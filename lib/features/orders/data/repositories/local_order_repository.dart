import '../../../../core/data/hive_database.dart';
import '../../domain/entities/restaurant_order.dart';
import '../../domain/repositories/order_repository.dart';

class LocalOrderRepository implements OrderRepository {
  @override
  Future<List<RestaurantOrder>> getOrders() async {
    final orders = HiveDatabase.ordersBox.values.map((raw) {
      if (raw is! Map) {
        throw const FormatException('A saved order has an invalid format.');
      }
      return RestaurantOrder.fromMap(Map<dynamic, dynamic>.from(raw));
    }).toList();
    orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return orders;
  }

  @override
  Future<void> submitOrder(RestaurantOrder order) async {
    await HiveDatabase.ordersBox.put(order.id, order.toMap());
  }

  @override
  Future<void> updateOrder(RestaurantOrder order) async {
    if (!HiveDatabase.ordersBox.containsKey(order.id)) {
      throw StateError('This order is no longer available on this device.');
    }
    await HiveDatabase.ordersBox.put(order.id, order.toMap());
  }
}
