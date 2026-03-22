import 'package:equatable/equatable.dart';

/// Unit used to measure/sell a product.
enum QuantityUnit {
  piece,  // individual items
  kg,     // kilograms
  liter,  // litres
  box,    // boxes / cartons
}

extension QuantityUnitLabel on QuantityUnit {
  String get label {
    switch (this) {
      case QuantityUnit.piece:
        return 'Piece';
      case QuantityUnit.kg:
        return 'KG';
      case QuantityUnit.liter:
        return 'Litre';
      case QuantityUnit.box:
        return 'Box';
    }
  }

  String get shortLabel {
    switch (this) {
      case QuantityUnit.piece:
        return 'pc';
      case QuantityUnit.kg:
        return 'kg';
      case QuantityUnit.liter:
        return 'L';
      case QuantityUnit.box:
        return 'box';
    }
  }
}

class Product extends Equatable {
  final String id;
  final String name;
  final String barcode;
  final double price;
  final int stock;
  final QuantityUnit unit;
  final String? categoryId;
  /// True when the record needs to be pushed to Firestore.
  final bool pendingSync;

  const Product({
    required this.id,
    required this.name,
    required this.barcode,
    required this.price,
    this.stock = 0,
    this.unit = QuantityUnit.piece,
    this.categoryId,
    this.pendingSync = false,
  });

  Product copyWith({
    String? id,
    String? name,
    String? barcode,
    double? price,
    int? stock,
    QuantityUnit? unit,
    String? categoryId,
    bool? pendingSync,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      unit: unit ?? this.unit,
      categoryId: categoryId ?? this.categoryId,
      pendingSync: pendingSync ?? this.pendingSync,
    );
  }

  @override
  List<Object?> get props => [id, name, barcode, price, stock, unit, categoryId, pendingSync];
}
