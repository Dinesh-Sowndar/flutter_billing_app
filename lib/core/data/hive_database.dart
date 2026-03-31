import 'package:hive_flutter/hive_flutter.dart';
import '../../features/product/data/models/product_model.dart';
import '../../features/product/data/models/category_model.dart';
import '../../features/shop/data/models/shop_model.dart';
import '../../features/billing/data/models/transaction_model.dart';
import '../../features/customer/data/models/customer_model.dart';
import '../../features/supplier/data/models/supplier_model.dart';
import '../../features/supplier/data/models/supplier_purchase_model.dart';

class HiveDatabase {
  static const String productBoxName = 'products';
  static const String categoryBoxName = 'categories';
  static const String shopBoxName = 'shop';
  static const String settingsBoxName = 'settings';
  static const String transactionBoxName = 'transactions';
  static const String customerBoxName = 'customers';
  static const String supplierBoxName = 'suppliers';
  static const String supplierPurchaseBoxName = 'supplierPurchases';
  static const String onboardingCompletedKey = 'onboarding_completed';

  static Future<void> init() async {
    await Hive.initFlutter();

    // Register Adapters
    Hive.registerAdapter(ProductModelAdapter());
    Hive.registerAdapter(CategoryModelAdapter());
    Hive.registerAdapter(ShopModelAdapter());
    Hive.registerAdapter(TransactionItemModelAdapter());
    Hive.registerAdapter(TransactionModelAdapter());
    Hive.registerAdapter(CustomerModelAdapter());
    Hive.registerAdapter(SupplierModelAdapter());
    Hive.registerAdapter(SupplierPurchaseItemModelAdapter());
    Hive.registerAdapter(SupplierPurchaseModelAdapter());

    // Open Boxes
    await Hive.openBox<ProductModel>(productBoxName);
    await Hive.openBox<CategoryModel>(categoryBoxName);
    await Hive.openBox<ShopModel>(shopBoxName);
    await Hive.openBox(settingsBoxName);
    await Hive.openBox<TransactionModel>(transactionBoxName);
    await Hive.openBox<CustomerModel>(customerBoxName);
    await Hive.openBox<SupplierModel>(supplierBoxName);
    await Hive.openBox<SupplierPurchaseModel>(supplierPurchaseBoxName);
  }

  static Box<ProductModel> get productBox =>
      Hive.box<ProductModel>(productBoxName);
  static Box<CategoryModel> get categoryBox =>
      Hive.box<CategoryModel>(categoryBoxName);
  static Box<ShopModel> get shopBox => Hive.box<ShopModel>(shopBoxName);
  static Box get settingsBox => Hive.box(settingsBoxName);
  static Box<TransactionModel> get transactionBox =>
      Hive.box<TransactionModel>(transactionBoxName);
  static Box<CustomerModel> get customerBox =>
      Hive.box<CustomerModel>(customerBoxName);
  static Box<SupplierModel> get supplierBox =>
      Hive.box<SupplierModel>(supplierBoxName);
  static Box<SupplierPurchaseModel> get supplierPurchaseBox =>
      Hive.box<SupplierPurchaseModel>(supplierPurchaseBoxName);

  static bool hasUnsyncedData() {
    final hasUnsyncedProducts =
        productBox.values.any((product) => product.pendingSync);
    final hasUnsyncedCategories =
        categoryBox.values.any((category) => category.pendingSync);
    final hasUnsyncedTransactions =
        transactionBox.values.any((transaction) => transaction.pendingSync);
    final hasUnsyncedCustomers =
        customerBox.values.any((customer) => customer.pendingSync);
    final hasUnsyncedSuppliers =
        supplierBox.values.any((supplier) => supplier.pendingSync);
    final hasUnsyncedSupplierPurchases =
        supplierPurchaseBox.values.any((p) => p.pendingSync);
    final hasUnsyncedShop =
        settingsBox.get('pendingShopSync', defaultValue: false) == true;
    return hasUnsyncedProducts ||
        hasUnsyncedCategories ||
        hasUnsyncedTransactions ||
        hasUnsyncedCustomers ||
        hasUnsyncedSuppliers ||
        hasUnsyncedSupplierPurchases ||
        hasUnsyncedShop;
  }

  static Future<void> clearAllData() async {
    // Preserve app-level onboarding state across logout.
    final onboardingCompleted =
        settingsBox.get(onboardingCompletedKey, defaultValue: false) == true;

    await productBox.clear();
    await categoryBox.clear();
    await shopBox.clear();
    await settingsBox.clear();
    await transactionBox.clear();
    await customerBox.clear();
    await supplierBox.clear();
    await supplierPurchaseBox.clear();

    if (onboardingCompleted) {
      await settingsBox.put(onboardingCompletedKey, true);
    }
  }
}
