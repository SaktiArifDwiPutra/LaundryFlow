import '../models/customer.dart';
import '../models/order.dart';
import '../models/order_option.dart';
import '../models/order_status.dart';
import '../models/service.dart';

class OrderLineInput {
  const OrderLineInput({required this.service, required this.qty});

  final Service service;
  final double qty;
}

enum OrderSort { createdAt, dueAt }

class OrderSummary {
  const OrderSummary({
    required this.byStatus,
    required this.overdue,
    required this.express,
  });

  final Map<OrderStatus, int> byStatus;
  final int overdue;
  final int express;

  int get active => byStatus.values.fold(0, (a, b) => a + b);
}

abstract class OrderRepository {
  Future<List<Order>> list({
    OrderStatus? status,
    String q = '',
    bool activeOnly = false,
    OrderSort sort = OrderSort.createdAt,
  });

  Future<Order> get(int id);

  Future<Order> create({
    required Customer customer,
    required List<OrderLineInput> lines,
    String notes = '',
    OrderPriority priority = OrderPriority.regular,
    Fulfillment fulfillment = Fulfillment.pickup,
    String deliveryAddress = '',
    int deliveryFee = 0,
  });

  Future<Order> advanceStatus(int id, OrderStatus to);

  Future<Order> setFulfillment(
    int id,
    Fulfillment fulfillment, {
    String deliveryAddress = '',
    int deliveryFee = 0,
  });

  Future<OrderSummary> summary();
}

class InvalidTransitionException implements Exception {
  const InvalidTransitionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class OrderValidationException implements Exception {
  const OrderValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}