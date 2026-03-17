import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failure.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/entities/app_user.dart';

class FirebaseAuthRepositoryImpl implements AuthRepository {
  final firebase_auth.FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  FirebaseAuthRepositoryImpl({
    firebase_auth.FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  })  : _firebaseAuth = firebaseAuth ?? firebase_auth.FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  /// Fetches the AppUser from Firestore.
  /// If [failIfMissing] is true (used during sign-in), returns null instead of
  /// auto-creating the record — so deleted/blocked users cannot log back in.
  Future<AppUser?> _getAppUser(
    firebase_auth.User firebaseUser, {
    bool failIfMissing = false,
  }) async {
    try {
      final doc = await _firestore.collection('users').doc(firebaseUser.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        final status = data['status'] as String? ?? 
            ((data['deleted'] as bool? ?? false) ? 'deleted' : 'active');
        
        // Block access for soft-deleted or disabled accounts during explicit sign-in.
        if (failIfMissing && (status == 'deleted' || status == 'disabled')) return null;
        
        return AppUser(
          id: firebaseUser.uid,
          email: firebaseUser.email ?? '',
          status: status,
          deleted: status == 'deleted',
        );
      } else {
        // During an explicit sign-in we do NOT recreate the document —
        // a missing doc means the admin hard-deleted this account.
        if (failIfMissing) return null;

        // On app-startup stream (e.g. legacy account with no Firestore doc)
        // create the document with the default role.
        await _firestore.collection('users').doc(firebaseUser.uid).set({
          'email': firebaseUser.email,
          'status': 'active',
          'deleted': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        return AppUser(
          id: firebaseUser.uid,
          email: firebaseUser.email ?? '',
          status: 'active',
        );
      }
    } catch (_) {
      if (failIfMissing) return null;
      return AppUser(
        id: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        status: 'active',
      );
    }
  }

  @override
  Stream<AppUser?> get user {
    late final StreamController<AppUser?> controller;
    StreamSubscription<firebase_auth.User?>? authSubscription;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? userDocSubscription;

    controller = StreamController<AppUser?>(
      onListen: () {
        authSubscription = _firebaseAuth.authStateChanges().listen(
          (firebaseUser) {
            userDocSubscription?.cancel();
            userDocSubscription = null;

            if (firebaseUser == null) {
              controller.add(null);
              return;
            }

            userDocSubscription = _firestore
                .collection('users')
                .doc(firebaseUser.uid)
                .snapshots()
                .listen(
                  (doc) {
                    if (!doc.exists) {
                      // A missing doc means the account record was removed by admin.
                      // Emit a deleted status so AuthBloc can force immediate logout.
                      controller.add(
                        AppUser(
                          id: firebaseUser.uid,
                          email: firebaseUser.email ?? '',
                          status: 'deleted',
                          deleted: true,
                        ),
                      );
                      return;
                    }

                    final data = doc.data()!;
                    final status = data['status'] as String? ??
                        ((data['deleted'] as bool? ?? false) ? 'deleted' : 'active');

                    controller.add(
                      AppUser(
                        id: firebaseUser.uid,
                        email: firebaseUser.email ?? '',
                        status: status,
                        deleted: status == 'deleted',
                      ),
                    );
                  },
                  onError: controller.addError,
                );
          },
          onError: controller.addError,
        );
      },
      onCancel: () async {
        await userDocSubscription?.cancel();
        await authSubscription?.cancel();
      },
    );

    return controller.stream;
  }

  @override
  AppUser? get currentUser {
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser == null) return null;
    // We can't do async fetch in a synchronous getter, so we return a default AppUser
    // The stream is the primary source of truth for the updated role.
    return AppUser(
      id: firebaseUser.uid,
      email: firebaseUser.email ?? '',
    );
  }

  @override
  Future<Either<Failure, AppUser>> signInWithEmailAndPassword({
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
        final appUser = await _getAppUser(
          userCredential.user!,
          failIfMissing: true,
        );
        if (appUser == null) {
          // Firestore doc was deleted by admin — revoke session and deny access.
          await _firebaseAuth.signOut();
          return const Left(
            ServerFailure('This account has been removed. Please contact your administrator.'),
          );
        }
        return Right(appUser);
      } else {
        return const Left(ServerFailure('Failed to sign in. User is null.'));
      }
    } on TimeoutException catch (e) {
      return Left(ServerFailure(e.message ?? 'Sign-in timed out.'));
    } on firebase_auth.FirebaseAuthException catch (e) {
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
  Future<Either<Failure, AppUser>> signUpWithEmailAndPassword({
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
        final appUser = await _getAppUser(userCredential.user!);
        if (appUser == null) {
          return const Left(ServerFailure('Failed to sign up. Please try again.'));
        }
        return Right(appUser);
      } else {
        return const Left(ServerFailure('Failed to sign up. User is null.'));
      }
    } on TimeoutException catch (e) {
      return Left(ServerFailure(e.message ?? 'Sign-up timed out.'));
    } on firebase_auth.FirebaseAuthException catch (e) {
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
