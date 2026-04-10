import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../../core/data/hive_database.dart';
import '../../domain/entities/app_user.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;
  late final StreamSubscription<AppUser?> _userSubscription;

  /// How many upcoming AuthUserChanged events from the stream to suppress.
  /// Used to prevent authStateChanges from overriding explicit sign-in/out results.
  int _suppressUserChanges = 0;

  AuthBloc({required AuthRepository authRepository})
      : _authRepository = authRepository,
        super(const AuthState.initial()) {
    on<AuthUserChanged>(_onUserChanged);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthSignUpRequested>(_onSignUpRequested);

    _userSubscription = _authRepository.user.listen(
      (user) {
        add(AuthUserChanged(user));
      },
      onError: (_, __) {
        add(const AuthUserChanged(null));
      },
    );
  }

  void _onUserChanged(AuthUserChanged event, Emitter<AuthState> emit) {
    if (_suppressUserChanges > 0) {
      _suppressUserChanges--;
      return;
    }

    final user = event.user;

    if (user != null) {
      // Enforcement: If account is deleted or disabled, sign out immediately.
      // This responds to real-time status changes in Firestore.
      if (user.status != 'active') {
        add(const AuthLogoutRequested());
        return;
      }
      emit(AuthState.authenticated(user));
    } else {
      emit(const AuthState.unauthenticated());
    }
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthState.loading());

    // Sign out first so any persisted session does not bypass credential
    // validation. Suppress the null event that authStateChanges emits from
    // signOut — we emit authenticated directly from the result below.
    _suppressUserChanges++;
    await _authRepository.signOut();

    final result = await _authRepository.signInWithEmailAndPassword(
      email: event.email,
      password: event.password,
    );

    result.fold(
      (failure) {
        emit(AuthState.error(failure.message));
      },
      (user) {
        // Emit authenticated directly. The stream may also emit a user
        // event but Equatable will block the duplicate re-emission.
        emit(AuthState.authenticated(user));
      },
    );
  }

  Future<void> _onSignUpRequested(
    AuthSignUpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthState.loading());
    final result = await _authRepository.signUpWithEmailAndPassword(
      email: event.email,
      password: event.password,
    );

    result.fold(
      (failure) => emit(AuthState.error(failure.message)),
      (user) => emit(AuthState.authenticated(user)),
    );
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    // Always sign out first — clearAllData is best-effort and must not
    // prevent the Firebase session from being terminated.
    await _authRepository.signOut();
    // Clear local Hive data after signing out (ignore any Hive errors).
    try {
      await HiveDatabase.clearAllData();
    } catch (_) {
      // Hive errors on clear are non-fatal; the session is already ended.
    }
  }

  @override
  Future<void> close() {
    _userSubscription.cancel();
    return super.close();
  }
}
