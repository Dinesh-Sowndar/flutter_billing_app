import 'package:equatable/equatable.dart';
import 'package:billing_app/features/product/domain/entities/product.dart';

class CartItem extends Equatable {
  final Product product;
  final double quantity;
  final double secondaryQuantity;

  const CartItem({
    required this.product,
    this.quantity = 1,
    this.secondaryQuantity = 0,
  });

  double get total => product.price * quantity;

  CartItem copyWith({
    Product? product,
    double? quantity,
    double? secondaryQuantity,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      secondaryQuantity: secondaryQuantity ?? this.secondaryQuantity,
    );
  }

  @override
  List<Object> get props => [product, quantity, secondaryQuantity];
}
