import 'package:equatable/equatable.dart';

enum OrderStatus { received, preparing, ready, completed, cancelled }

class RestaurantOrderItem extends Equatable {
  final String productId;
  final String name;
  final double unitPrice;
  final int quantity;

  const RestaurantOrderItem({
    required this.productId,
    required this.name,
    required this.unitPrice,
    required this.quantity,
  });

  double get total => unitPrice * quantity;

  Map<String, Object> toMap() => {
        'productId': productId,
        'name': name,
        'unitPrice': unitPrice,
        'quantity': quantity,
      };

  factory RestaurantOrderItem.fromMap(Map<dynamic, dynamic> map) {
    return RestaurantOrderItem(
      productId: map['productId'] as String,
      name: map['name'] as String,
      unitPrice: (map['unitPrice'] as num).toDouble(),
      quantity: map['quantity'] as int,
    );
  }

  @override
  List<Object?> get props => [productId, name, unitPrice, quantity];
}

class RestaurantOrder extends Equatable {
  final String id;
  final String customerName;
  final String requirements;
  final List<RestaurantOrderItem> items;
  final OrderStatus status;
  final DateTime createdAt;

  const RestaurantOrder({
    required this.id,
    required this.customerName,
    required this.requirements,
    required this.items,
    required this.status,
    required this.createdAt,
  });

  double get total => items.fold(0, (sum, item) => sum + item.total);
  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  RestaurantOrder copyWith({OrderStatus? status}) => RestaurantOrder(
        id: id,
        customerName: customerName,
        requirements: requirements,
        items: items,
        status: status ?? this.status,
        createdAt: createdAt,
      );

  Map<String, Object> toMap() => {
        'id': id,
        'customerName': customerName,
        'requirements': requirements,
        'items': items.map((item) => item.toMap()).toList(),
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory RestaurantOrder.fromMap(Map<dynamic, dynamic> map) {
    return RestaurantOrder(
      id: map['id'] as String,
      customerName: map['customerName'] as String,
      requirements: map['requirements'] as String? ?? '',
      items: (map['items'] as List)
          .map((item) => RestaurantOrderItem.fromMap(
              Map<dynamic, dynamic>.from(item as Map)))
          .toList(),
      status: _statusFromValue(map['status']),
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  @override
  List<Object?> get props =>
      [id, customerName, requirements, items, status, createdAt];
}

OrderStatus _statusFromValue(Object? value) {
  for (final status in OrderStatus.values) {
    if (status.name == value) return status;
  }
  throw FormatException('Unknown saved order status: $value');
}
