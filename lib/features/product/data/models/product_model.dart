// ignore_for_file: overridden_fields
import 'package:hive/hive.dart';
import 'package:billing_app/features/product/domain/entities/product.dart';

part 'product_model.g.dart'; // Hive generator

@HiveType(typeId: 0)
class ProductModel extends Product {
  @override
  @HiveField(0)
  final String id;
  @override
  @HiveField(1)
  final String name;
  @override
  @HiveField(2)
  final String barcode;
  @override
  @HiveField(3)
  final double price;
  @override
  @HiveField(4)
  final int stock;
  /// Stored as int index of [QuantityUnit] enum (0=piece,1=kg,2=liter,3=box).
  @HiveField(5)
  final int unitIndex;
  @HiveField(7)
  final String? categoryId;
  /// Whether this record hasn't been synced to Firestore yet.
  @override
  @HiveField(6)
  final bool pendingSync;

  ProductModel({
    required this.id,
    required this.name,
    required this.barcode,
    required this.price,
    required this.stock,
    this.unitIndex = 0,
    this.categoryId,
    this.pendingSync = false,
  }) : super(
          id: id,
          name: name,
          barcode: barcode,
          price: price,
          stock: stock,
          unit: QuantityUnit.values[unitIndex > 3 ? 0 : unitIndex],
          categoryId: categoryId,
          pendingSync: pendingSync,
        );

  factory ProductModel.fromEntity(Product product) {
    return ProductModel(
      id: product.id,
      name: product.name,
      barcode: product.barcode,
      price: product.price,
      stock: product.stock,
      unitIndex: product.unit.index,
      categoryId: product.categoryId,
      pendingSync: product.pendingSync,
    );
  }

  factory ProductModel.fromFirestore(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id'] as String,
      name: map['name'] as String,
      barcode: map['barcode'] as String,
      price: (map['price'] as num).toDouble(),
      stock: (map['stock'] as num? ?? 0).toInt(),
      unitIndex: (map['unitIndex'] as num? ?? 0).toInt(),
      categoryId: map['categoryId'] as String?,
      pendingSync: false,
    );
  }

  Map<String, dynamic> toFirestore(String userId) => {
        'id': id,
        'name': name,
        'barcode': barcode,
        'price': price,
        'stock': stock,
        'unitIndex': unitIndex,
        'categoryId': categoryId,
        'userId': userId,
        'updatedAt': DateTime.now().toIso8601String(),
      };

  Product toEntity() {
    return Product(
      id: id,
      name: name,
      barcode: barcode,
      price: price,
      stock: stock,
      unit: QuantityUnit.values[unitIndex > 3 ? 0 : unitIndex],
      categoryId: categoryId,
      pendingSync: pendingSync,
    );
  }
}
