import 'package:equatable/equatable.dart';

class Product extends Equatable {
  final String
      id; // Using barcode as ID usually, but keeping separate ID is safer
  final String name;
  final String barcode;
  final double price;
  final int stock; // Optional implementation detail
  final String description;
  final String category;
  final bool isAvailable;

  const Product({
    required this.id,
    required this.name,
    required this.barcode,
    required this.price,
    this.stock = 0,
    this.description = '',
    this.category = 'Other',
    this.isAvailable = true,
  });

  @override
  List<Object?> get props =>
      [id, name, barcode, price, stock, description, category, isAvailable];
}
