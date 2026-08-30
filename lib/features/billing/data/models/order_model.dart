import 'package:hive/hive.dart';
import 'package:billing_app/features/billing/domain/entities/order_entity.dart';
import 'package:billing_app/features/product/data/models/product_model.dart';

part 'order_model.g.dart';

@HiveType(typeId: 2)
class OrderItemModel extends HiveObject {
  @HiveField(0)
  final ProductModel product;
  @HiveField(1)
  final int quantity;

  OrderItemModel({
    required this.product,
    required this.quantity,
  });

  factory OrderItemModel.fromEntity(OrderItem entity) {
    return OrderItemModel(
      product: ProductModel.fromEntity(entity.product),
      quantity: entity.quantity,
    );
  }

  OrderItem toEntity() {
    return OrderItem(
      product: product.toEntity(),
      quantity: quantity,
    );
  }
}

@HiveType(typeId: 3)
class OrderModel extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final List<OrderItemModel> items;
  @HiveField(2)
  final double totalAmount;
  @HiveField(3)
  final DateTime dateTime;
  @HiveField(4)
  final String shopName;

  OrderModel({
    required this.id,
    required this.items,
    required this.totalAmount,
    required this.dateTime,
    required this.shopName,
  });

  factory OrderModel.fromEntity(OrderEntity entity) {
    return OrderModel(
      id: entity.id,
      items: entity.items.map((e) => OrderItemModel.fromEntity(e)).toList(),
      totalAmount: entity.totalAmount,
      dateTime: entity.dateTime,
      shopName: entity.shopName,
    );
  }

  OrderEntity toEntity() {
    return OrderEntity(
      id: id,
      items: items.map((e) => e.toEntity()).toList(),
      totalAmount: totalAmount,
      dateTime: dateTime,
      shopName: shopName,
    );
  }
}
