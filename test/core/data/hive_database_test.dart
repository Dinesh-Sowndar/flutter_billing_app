import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:billing_app/core/data/hive_database.dart';
import 'package:billing_app/features/product/data/models/product_model.dart';
import 'package:billing_app/features/billing/data/models/transaction_model.dart';
import 'package:billing_app/features/shop/data/models/shop_model.dart';

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

  test('hasUnsyncedData returns true when there is an unsynced product', () async {
    final product = ProductModel(
      id: '1',
      name: 'Test Product',
      barcode: '123',
      price: 10.0,
      stock: 5,
      unitIndex: 0,
      pendingSync: true,
    );
    await HiveDatabase.productBox.put('1', product);

    expect(HiveDatabase.hasUnsyncedData(), isTrue);
  });

  test('hasUnsyncedData returns false when all data is synced', () async {
    final product = ProductModel(
      id: '2',
      name: 'Test Product 2',
      barcode: '1234',
      price: 10.0,
      stock: 5,
      unitIndex: 0,
      pendingSync: false,
    );
    await HiveDatabase.productBox.put('2', product);

    expect(HiveDatabase.hasUnsyncedData(), isFalse);
  });

  test('clearAllData clears all boxes', () async {
    await HiveDatabase.settingsBox.put('key', 'value');
    expect(HiveDatabase.settingsBox.isNotEmpty, isTrue);

    await HiveDatabase.clearAllData();
    expect(HiveDatabase.settingsBox.isEmpty, isTrue);
  });
}
