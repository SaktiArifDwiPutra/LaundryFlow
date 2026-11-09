import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../models/customer.dart';
import '../models/order.dart';
import '../models/order_option.dart';
import '../models/order_status.dart';
import '../models/service.dart';
import 'invoice_repository.dart';
import 'odoo_invoice_repository.dart';
import 'order_repository.dart';

class OdooOrderRepository implements OrderRepository {
  OdooOrderRepository(this._api, {this.invoiceRepository});

  final ApiClient _api;
  final InvoiceRepository? invoiceRepository;

  @override
  Future<List<Order>> list({
    OrderStatus? status,
    String q = '',
    bool activeOnly = false,
    OrderSort sort = OrderSort.createdAt,
  }) async {
    final queryParams = <String, String>{'limit': '100'};
    if (status != null && status != OrderStatus.unknown) {
      queryParams['state'] = status.code;
    }
    if (q.trim().isNotEmpty) {
      queryParams['q'] = q.trim();
    }

    final Map<String, dynamic> json;
    try {
      json = await _api.get('/api/laundry/orders', query: queryParams);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return const [];
      rethrow;
    }

    final data = json['data'] as List<dynamic>? ?? const [];
    var orders = [
      for (final item in data) Order.fromJson(item as Map<String, dynamic>),
    ];

    if (activeOnly) {
      orders = orders
          .where((o) =>
              o.status != OrderStatus.completed &&
              o.status != OrderStatus.unknown)
          .toList();
    }

    if (invoiceRepository is OdooInvoiceRepository) {
      final odooInv = invoiceRepository as OdooInvoiceRepository;
      orders = orders.map((o) {
        final cached = odooInv.getCached(o.id);
        if (cached != null) {
          return o.copyWith(
            paymentStatus: cached.paymentState,
            paymentMethod: cached.paymentMethod,
            amountPaid: cached.amountPaid,
            amountDue: cached.amountDue,
          );
        }
        return o;
      }).toList();
    }

    orders.sort((a, b) {
      if (sort == OrderSort.dueAt) {
        if (a.dueAt == null && b.dueAt == null) return 0;
        if (a.dueAt == null) return 1;
        if (b.dueAt == null) return -1;
        return a.dueAt!.compareTo(b.dueAt!);
      }
      return b.createdAt.compareTo(a.createdAt);
    });

    return orders;
  }

  @override
  Future<Order> get(int id) async {
    final json = await _api.get('/api/laundry/orders/$id');
    final data = json['data'];
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Data pesanan tidak valid.');
    }
    var order = Order.fromJson(data);
    if (invoiceRepository is OdooInvoiceRepository) {
      final cached = (invoiceRepository as OdooInvoiceRepository).getCached(id);
      if (cached != null) {
        order = order.copyWith(
          paymentStatus: cached.paymentState,
          paymentMethod: cached.paymentMethod,
          amountPaid: cached.amountPaid,
          amountDue: cached.amountDue,
        );
      }
    }
    return order;
  }

  @override
  Future<Order> create({
    required Customer customer,
    required List<OrderLineInput> lines,
    String notes = '',
    OrderPriority priority = OrderPriority.regular,
    Fulfillment fulfillment = Fulfillment.pickup,
    String deliveryAddress = '',
    int deliveryFee = 0,
  }) async {
    if (lines.isEmpty) {
      throw const OrderValidationException('Pilih minimal satu layanan.');
    }

    final speedCode = (priority == OrderPriority.sameDay ||
            priority == OrderPriority.express)
        ? 'same_day'
        : 'regular';

    final linesPayload = <Map<String, dynamic>>[];
    for (final l in lines) {
      final s = l.service;
      final lineMap = <String, dynamic>{
        'product_template_id': s.id,
      };

      switch (s.pricingType) {
        case PricingType.weight:
          lineMap['weight'] = l.weight ?? 0.0;
          lineMap['quantity'] = l.weight ?? 0.0;
        case PricingType.unit:
          lineMap['quantity'] = l.quantity ?? 1.0;
        case PricingType.area:
          lineMap['length'] = l.length ?? 0.0;
          lineMap['width'] = l.width ?? 0.0;
          lineMap['quantity'] = (l.length ?? 0.0) * (l.width ?? 0.0);
      }

      if (l.itemDetails.trim().isNotEmpty) {
        lineMap['item_details'] = l.itemDetails.trim();
      }
      linesPayload.add(lineMap);
    }

    final isDelivery = fulfillment == Fulfillment.delivery;
    final body = <String, dynamic>{
      'partner_id': customer.id,
      'service_speed': speedCode,
      'delivery_type': isDelivery ? 'delivery' : 'pickup',
      if (isDelivery && deliveryAddress.trim().isNotEmpty)
        'delivery_address': deliveryAddress.trim(),
      if (isDelivery && deliveryFee > 0)
        'delivery_fee': deliveryFee,
      if (notes.trim().isNotEmpty) 'notes': notes.trim(),
      'lines': linesPayload,
    };

    final json = await _api.post('/api/laundry/orders', body: body);
    final data = json['data'] as Map<String, dynamic>?;
    final orderId = data?['id'] as int?;

    if (orderId != null) {
      try {
        return await get(orderId);
      } catch (_) {
        return Order.fromJson(data!);
      }
    }
    if (data != null) {
      return Order.fromJson(data);
    }
    throw const ApiException('Gagal memproses respons pembuatan pesanan.');
  }

  @override
  Future<Order> advanceStatus(int id, OrderStatus to) async {
    try {
      await _api.patch(
        '/api/laundry/orders/$id/status',
        body: {'to': to.code},
      );
      return await get(id);
    } on ApiException catch (e) {
      if (e.statusCode == 409 || e.statusCode == 400) {
        throw InvalidTransitionException(e.message);
      }
      rethrow;
    }
  }

  @override
  Future<Order> setFulfillment(
    int id,
    Fulfillment fulfillment, {
    String deliveryAddress = '',
    int deliveryFee = 0,
  }) async {
    final isDelivery = fulfillment == Fulfillment.delivery;
    final body = <String, dynamic>{
      'delivery_type': isDelivery ? 'delivery' : 'pickup',
      if (isDelivery && deliveryAddress.trim().isNotEmpty)
        'delivery_address': deliveryAddress.trim(),
      'delivery_fee': isDelivery ? deliveryFee : 0,
    };

    try {
      await _api.patch('/api/laundry/orders/$id/delivery', body: body);
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        await _api.patch('/api/orders/$id/delivery', body: body);
      } else {
        rethrow;
      }
    }
    return get(id);
  }

  @override
  Future<OrderSummary> summary() async {
    final orders = await list(activeOnly: true);
    final byStatus = <OrderStatus, int>{};
    var overdue = 0;
    var express = 0;

    for (final o in orders) {
      final s = o.status;
      if (s == OrderStatus.completed || s == OrderStatus.unknown) continue;
      byStatus[s] = (byStatus[s] ?? 0) + 1;
      if (o.isOverdue) overdue++;
      if (o.priority == OrderPriority.sameDay ||
          o.priority == OrderPriority.express) {
        express++;
      }
    }
    return OrderSummary(byStatus: byStatus, overdue: overdue, express: express);
  }
}

