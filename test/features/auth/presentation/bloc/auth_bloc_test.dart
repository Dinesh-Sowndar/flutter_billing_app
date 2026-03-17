import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:billing_app/core/data/hive_database.dart';
import 'package:billing_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:billing_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:billing_app/core/error/failure.dart';
import 'package:fpdart/fpdart.dart';
import 'package:billing_app/features/product/data/models/product_model.dart';
import 'package:billing_app/features/billing/data/models/transaction_model.dart';
import 'package:billing_app/features/shop/data/models/shop_model.dart';

import 'package:billing_app/features/auth/domain/entities/app_user.dart';

class MockAuthRepository implements AuthRepository {
  bool signOutCalled = false;
  
  @override
  Stream<AppUser?> get user => const Stream.empty();

  @override
  AppUser? get currentUser => null;

  @override
  Future<Either<Failure, AppUser>> signInWithEmailAndPassword({required String email, required String password}) async {
    return Left(ServerFailure('Not implemented'));
  }

  @override
  Future<Either<Failure, AppUser>> signUpWithEmailAndPassword({required String email, required String password, String role = 'user'}) async {
    return Left(ServerFailure('Not implemented'));
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    signOutCalled = true;
    return const Right(null);
  }
}

void main() {
  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp();
    Hive.init(tempDir.path);
    // Register Adapters
    Hive.registerAdapter(ProductModelAdapter());
    Hive.registerAdapter(ShopModelAdapter());
    Hive.registerAdapter(TransactionItemModelAdapter());
    Hive.registerAdapter(TransactionModelAdapter());

    // Open Boxes
    await Hive.openBox<ProductModel>(HiveDatabase.productBoxName);
    await Hive.openBox<ShopModel>(HiveDatabase.shopBoxName);
    await Hive.openBox(HiveDatabase.settingsBoxName);
    await Hive.openBox<TransactionModel>(HiveDatabase.transactionBoxName);
  });

  tearDown(() async {
    await HiveDatabase.clearAllData();
  });

  tearDownAll(() async {
    await Hive.close();
  });

  test('AuthLogoutRequested clears Hive data and signs out', () async {
    // Arrange
    final mockRepo = MockAuthRepository();
    final bloc = AuthBloc(authRepository: mockRepo);
    
    await HiveDatabase.settingsBox.put('test_key', 'test_value');
    expect(HiveDatabase.settingsBox.isNotEmpty, isTrue);

    // Act
    bloc.add(const AuthLogoutRequested());
    
    // Wait for event to be processed
    await Future.delayed(const Duration(milliseconds: 100));

    // Assert
    expect(mockRepo.signOutCalled, isTrue);
    expect(HiveDatabase.settingsBox.isEmpty, isTrue);
    
    await bloc.close();
  });
}
