import 'package:hive/hive.dart';
import '../../domain/entities/product.dart';

part 'product_model.g.dart'; // Hive generator

@HiveType(typeId: 0, adapterName: 'ProductModelAdapter')
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
  @override
  @HiveField(5)
  final String? description;
  @override
  @HiveField(6)
  final String? imageUrl;
  @override
  @HiveField(7)
  final String? category;
  @override
  @HiveField(8)
  final double? taxPercent;

  const ProductModel({
    required this.id,
    required this.name,
    required this.barcode,
    required this.price,
    required this.stock,
    this.description,
    this.imageUrl,
    this.taxPercent,
    this.category,
  }) : super(
          id: id,
          name: name,
          barcode: barcode,
          price: price,
          description: description,
          imageUrl: imageUrl,
          stock: stock,
          category: category,
          taxPercent: taxPercent,
        );

  factory ProductModel.fromEntity(Product product) {
    return ProductModel(
      id: product.id,
      name: product.name,
      barcode: product.barcode,
      price: product.price,
      stock: product.stock,
      description: product.description,
      imageUrl: product.imageUrl,
      category: product.category,
      taxPercent: product.taxPercent,
    );
  }

  Product toEntity() {
    return Product(
      id: id,
      name: name,
      barcode: barcode,
      price: price,
      description: description,
      imageUrl: imageUrl,
      stock: stock,
      category: category,
      taxPercent: taxPercent,
    );
  }
}
