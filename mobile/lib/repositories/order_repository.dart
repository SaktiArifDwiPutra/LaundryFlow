import '../models/order.dart';
import '../models/order_status.dart';

abstract class OrderRepository {
  Future<List<Order>> list({OrderStatus? status});
  Future<Order> get(int id);
  Future<Order> advanceStatus(int id, OrderStatus to);
}

class InvalidTransitionException implements Exception {
  const InvalidTransitionException(this.message);

  final String message;

  @override
  String toString() => message;
}