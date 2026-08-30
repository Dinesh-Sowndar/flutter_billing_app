import 'package:equatable/equatable.dart';
import 'package:billing_app/features/product/domain/entities/product.dart';

class OrderItem extends Equatable {
  final Product product;
  final int quantity;

  const OrderItem({
    required this.product,
    required this.quantity,
  });

  double get total => product.price * quantity;

  @override
  List<Object?> get props => [product, quantity];
}

class OrderEntity extends Equatable {
  final String id;
  final List<OrderItem> items;
  final double totalAmount;
  final DateTime dateTime;
  final String shopName;

  const OrderEntity({
    required this.id,
    required this.items,
    required this.totalAmount,
    required this.dateTime,
    required this.shopName,
  });

  @override
  List<Object?> get props => [id, items, totalAmount, dateTime, shopName];
}
