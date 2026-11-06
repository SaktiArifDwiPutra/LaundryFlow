import '../models/customer.dart';
import '../models/order.dart';
import '../models/order_option.dart';
import '../models/order_status.dart';
import '../models/service.dart';

/// Satu baris isian saat membuat pesanan. Field yang dipakai mengikuti
/// `service.pricingType`: berat (kg), jumlah (pcs/set), atau panjang x lebar (m²).
class OrderLineInput {
  const OrderLineInput({
    required this.service,
    this.weight,
    this.quantity,
    this.length,
    this.width,
    this.itemDetails = '',
  });

  final Service service;
  final double? weight;
  final double? quantity;
  final double? length;
  final double? width;
  final String itemDetails;

  /// Angka yang dikalikan dengan harga satuan (kg, pcs, atau m²).
  double get billableQty => switch (service.pricingType) {
        PricingType.weight => weight ?? 0,
        PricingType.unit => quantity ?? 0,
        PricingType.area => (length ?? 0) * (width ?? 0),
      };
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