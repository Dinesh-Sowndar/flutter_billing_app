import 'package:hive_flutter/hive_flutter.dart';
import 'package:billing_app/features/product/data/models/product_model.dart';
import 'package:billing_app/features/shop/data/models/shop_model.dart';
import 'package:billing_app/features/billing/data/models/order_model.dart';

class HiveDatabase {
  static const String productBoxName = 'products';
  static const String shopBoxName = 'shop';
  static const String orderBoxName = 'orders';
  static const String settingsBoxName = 'settings';

  static Future<void> init() async {
    await Hive.initFlutter();

    // Register Adapters
    Hive.registerAdapter(ProductModelAdapter());
    Hive.registerAdapter(ShopModelAdapter());
    Hive.registerAdapter(OrderItemModelAdapter());
    Hive.registerAdapter(OrderModelAdapter());

    // Open Boxes
    await Hive.openBox<ProductModel>(productBoxName);
    await Hive.openBox<ShopModel>(shopBoxName);
    await Hive.openBox<OrderModel>(orderBoxName);
    await Hive.openBox(settingsBoxName); // Generic box for simple key-value
  }

  static Box<ProductModel> get productBox =>
      Hive.box<ProductModel>(productBoxName);
  static Box<ShopModel> get shopBox => Hive.box<ShopModel>(shopBoxName);
  static Box<OrderModel> get orderBox => Hive.box<OrderModel>(orderBoxName);
  static Box get settingsBox => Hive.box(settingsBoxName);
}
