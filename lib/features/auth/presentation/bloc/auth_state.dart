part of 'auth_bloc.dart';

enum AuthStatus { initial, unauthenticated, authenticated, loading, error }

class AuthState extends Equatable {
  final AuthStatus status;
  final AppUser? user;
  final String? errorMessage;

  const AuthState._({
    required this.status,
    this.user,
    this.errorMessage,
  });

  const AuthState.initial() : this._(status: AuthStatus.initial);

  const AuthState.unauthenticated()
      : this._(status: AuthStatus.unauthenticated);

  const AuthState.authenticated(AppUser user)
      : this._(status: AuthStatus.authenticated, user: user);

  const AuthState.loading() : this._(status: AuthStatus.loading);

  const AuthState.error(String message)
      : this._(status: AuthStatus.error, errorMessage: message);

  @override
  List<Object?> get props => [status, user, errorMessage];
}
