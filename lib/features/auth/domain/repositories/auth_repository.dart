import 'package:firebase_auth/firebase_auth.dart';
import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failure.dart';

abstract class AuthRepository {
  /// Stream of [User] which will emit the current user when
  /// the authentication state changes
  Stream<User?> get user;

  /// Returns the current cached user.
  User? get currentUser;

  /// Signs in a user with their [email] and [password].
  Future<Either<Failure, User>> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  /// Registers a new user with their [email] and [password].
  Future<Either<Failure, User>> signUpWithEmailAndPassword({
    required String email,
    required String password,
  });

  /// Signs out the current user.
  Future<Either<Failure, void>> signOut();
}
