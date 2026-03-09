import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failure.dart';
import '../../domain/repositories/auth_repository.dart';

class FirebaseAuthRepositoryImpl implements AuthRepository {
  final FirebaseAuth _firebaseAuth;

  FirebaseAuthRepositoryImpl({
    FirebaseAuth? firebaseAuth,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  @override
  Stream<User?> get user => _firebaseAuth.authStateChanges();

  @override
  User? get currentUser => _firebaseAuth.currentUser;

  @override
  Future<Either<Failure, User>> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _firebaseAuth
          .signInWithEmailAndPassword(
            email: email,
            password: password,
          )
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () => throw TimeoutException(
              'Sign-in timed out. Please check your connection and try again.',
            ),
          );
      
      if (userCredential.user != null) {
        return Right(userCredential.user!);
      } else {
        return const Left(ServerFailure('Failed to sign in. User is null.'));
      }
    } on TimeoutException catch (e) {
      return Left(ServerFailure(e.message ?? 'Sign-in timed out.'));
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        return const Left(ServerFailure('No user found for that email.'));
      } else if (e.code == 'wrong-password') {
        return const Left(ServerFailure('Wrong password provided for that user.'));
      } else if (e.code == 'invalid-email') {
        return const Left(ServerFailure('The email address is not valid.'));
      }
      return Left(ServerFailure(e.message ?? 'Authentication failed'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, User>> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _firebaseAuth
          .createUserWithEmailAndPassword(
            email: email,
            password: password,
          )
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () => throw TimeoutException(
              'Sign-up timed out. Please check your connection and try again.',
            ),
          );
      
      if (userCredential.user != null) {
        return Right(userCredential.user!);
      } else {
        return const Left(ServerFailure('Failed to sign up. User is null.'));
      }
    } on TimeoutException catch (e) {
      return Left(ServerFailure(e.message ?? 'Sign-up timed out.'));
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        return const Left(ServerFailure('The password provided is too weak.'));
      } else if (e.code == 'email-already-in-use') {
        return const Left(ServerFailure('The account already exists for that email.'));
      } else if (e.code == 'invalid-email') {
        return const Left(ServerFailure('The email address is not valid.'));
      }
      return Left(ServerFailure(e.message ?? 'Registration failed'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    try {
      await _firebaseAuth.signOut();
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
