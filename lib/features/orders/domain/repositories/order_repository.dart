import '../entities/restaurant_order.dart';

abstract interface class OrderRepository {
  Future<List<RestaurantOrder>> getOrders();
  Future<void> submitOrder(RestaurantOrder order);
  Future<void> updateOrder(RestaurantOrder order);
}
