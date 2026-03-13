import 'package:hive_flutter/hive_flutter.dart';
import '../../features/product/data/models/product_model.dart';
import '../../features/shop/data/models/shop_model.dart';
import '../../features/billing/data/models/transaction_model.dart';

class HiveDatabase {
  static const String productBoxName = 'products';
  static const String shopBoxName = 'shop';
  static const String settingsBoxName = 'settings';
  static const String transactionBoxName = 'transactions';

  static Future<void> init() async {
    await Hive.initFlutter();

    // Register Adapters
    Hive.registerAdapter(ProductModelAdapter());
    Hive.registerAdapter(ShopModelAdapter());
    Hive.registerAdapter(TransactionItemModelAdapter());
    Hive.registerAdapter(TransactionModelAdapter());

    // Open Boxes
    await Hive.openBox<ProductModel>(productBoxName);
    await Hive.openBox<ShopModel>(shopBoxName);
    await Hive.openBox(settingsBoxName); // Generic box for simple key-value
    await Hive.openBox<TransactionModel>(transactionBoxName);
  }

  static Box<ProductModel> get productBox =>
      Hive.box<ProductModel>(productBoxName);
  static Box<ShopModel> get shopBox => Hive.box<ShopModel>(shopBoxName);
  static Box get settingsBox => Hive.box(settingsBoxName);
  static Box<TransactionModel> get transactionBox =>
      Hive.box<TransactionModel>(transactionBoxName);

  static bool hasUnsyncedData() {
    final hasUnsyncedProducts =
        productBox.values.any((product) => product.pendingSync);
    final hasUnsyncedTransactions =
        transactionBox.values.any((transaction) => transaction.pendingSync);

    return hasUnsyncedProducts || hasUnsyncedTransactions;
  }

  static Future<void> clearAllData() async {
    await productBox.clear();
    await shopBox.clear();
    await settingsBox.clear();
    await transactionBox.clear();
  }
}
