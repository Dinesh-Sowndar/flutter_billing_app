import 'package:equatable/equatable.dart';

class Product extends Equatable {
  final String
      id; // Using barcode as ID usually, but keeping separate ID is safer
  final String name;
  final String barcode;
  final double price;
  final String? description; // Optional field for future use
  final String? imageUrl; // Optional field for future use
  final int stock; // Optional implementation detail
  // Nouveaux attributs
  final String? category;
  final double? taxPercent;

  const Product({
    required this.id,
    required this.name,
    required this.barcode,
    required this.price,
    this.description,
    this.imageUrl,
    this.stock = 0,
    this.category,
    this.taxPercent,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        barcode,
        price,
        description,
        imageUrl,
        stock,
        category,
        taxPercent
      ];
}
