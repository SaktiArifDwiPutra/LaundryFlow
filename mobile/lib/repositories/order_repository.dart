import '../models/customer.dart';
import '../models/order.dart';
import '../models/order_status.dart';
import '../models/service.dart';

class OrderLineInput {
  const OrderLineInput({required this.service, required this.qty});

  final Service service;
  final double qty;
}
abstract class OrderRepository {
  Future<List<Order>> list({OrderStatus? status, String q = ''});
  Future<Order> get(int id);
  Future<Order> create({
    required Customer customer,
    required List<OrderLineInput> lines,
    String notes = '',
  });
  Future<Order> advanceStatus(int id, OrderStatus to);
}

class InvalidTransitionException implements Exception {
  const InvalidTransitionException(this.message);

  final String message;

  @override
  String toString() => message;
}