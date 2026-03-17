import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failure.dart';
import '../entities/app_user.dart';

abstract class AuthRepository {
  /// Stream of [AppUser] which will emit the current user when
  /// the authentication state changes
  Stream<AppUser?> get user;

  /// Returns the current cached user.
  AppUser? get currentUser;

  /// Signs in a user with their [email] and [password].
  Future<Either<Failure, AppUser>> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  /// Registers a new user with their [email] and [password].
  Future<Either<Failure, AppUser>> signUpWithEmailAndPassword({
    required String email,
    required String password,
  });

  /// Signs out the current user.
  Future<Either<Failure, void>> signOut();
}
