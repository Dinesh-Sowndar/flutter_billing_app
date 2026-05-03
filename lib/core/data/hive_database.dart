import 'package:hive_flutter/hive_flutter.dart';
import '../../features/product/data/models/product_model.dart';
import '../../features/shop/data/models/shop_model.dart';

class HiveDatabase {
  static const String productBoxName = 'products';
  static const String shopBoxName = 'shop';
  static const String settingsBoxName = 'settings';

  static Future<void> init() async {
    await Hive.initFlutter(
        'billing_app_data'); // Custom directory for Hive data

    // Register Adapters
    Hive.registerAdapter(ProductModelAdapter());
    Hive.registerAdapter(ShopModelAdapter());

    // Open Boxes
    await Hive.openBox<ProductModel>(productBoxName);
    await Hive.openBox<ShopModel>(shopBoxName);
    await Hive.openBox(settingsBoxName); // Generic box for simple key-value
    // Migration
    await _migrateProductBoxDefaults();
  }

  static Box<ProductModel> get productBox =>
      Hive.box<ProductModel>(productBoxName);
  static Box<ShopModel> get shopBox => Hive.box<ShopModel>(shopBoxName);
  static Box get settingsBox => Hive.box(settingsBoxName);

  // Migration simple : donne des valeurs par défaut si null
  static Future<void> _migrateProductBoxDefaults() async {
    final box = Hive.box<ProductModel>(productBoxName);
    final keys = box.keys.toList();
    for (final key in keys) {
      final model = box.get(key);
      if (model != null) {
        final needsMigration =
            (model.category == null || model.taxPercent == null);
        if (needsMigration) {
          final migrated = ProductModel(
            id: model.id,
            name: model.name,
            barcode: model.barcode,
            price: model.price,
            stock: model.stock,
            description: model.description,
            imageUrl: model.imageUrl,
            category: model.category ?? 'Non catégorisé',
            taxPercent: model.taxPercent ?? 0.0,
          );
          await box.put(key, migrated);
        }
      }
    }
  }
}
