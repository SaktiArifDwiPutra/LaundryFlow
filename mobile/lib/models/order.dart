import 'order_option.dart';
import 'order_status.dart';

class OrderCustomer {
  const OrderCustomer({
    required this.id,
    required this.name,
    required this.phone,
  });

  final int id;
  final String name;
  final String phone;

  factory OrderCustomer.fromJson(Map<String, dynamic> json) {
    return OrderCustomer(
      id: json['id'] as int,
      name: json['name'] as String,
      phone: (json['phone'] as String?) ?? '',
    );
  }
}

class OrderLine {
  const OrderLine({
    required this.serviceId,
    required this.serviceName,
    required this.qty,
    required this.unit,
    required this.unitPrice,
    required this.subtotal,
  });

  final int serviceId;
  final String serviceName;
  final double qty;
  final String unit;
  final int unitPrice;
  final int subtotal;

  factory OrderLine.fromJson(Map<String, dynamic> json) {
    return OrderLine(
      serviceId: (json['product_id'] ?? json['service_id']) as int,
      serviceName: (json['product_name'] ?? json['service_name']) as String,
      qty: (json['qty'] as num).toDouble(),
      unit: ((json['uom'] ?? json['unit']) as String?) ?? '',
      unitPrice: (json['unit_price'] as num).round(),
      subtotal: (json['subtotal'] as num).round(),
    );
  }
}

class DeliveryInfo {
  const DeliveryInfo({
    required this.address,
    required this.fee,
    this.courierName,
  });

  final String address;
  final int fee;
  final String? courierName;

  factory DeliveryInfo.fromJson(Map<String, dynamic> json) {
    final courier = json['courier'];
    return DeliveryInfo(
      address: (json['address'] as String?) ?? '',
      fee: (json['fee'] as num?)?.round() ?? 0,
      courierName:
          courier is Map<String, dynamic> ? courier['name'] as String? : null,
    );
  }
}

class Order {
  const Order({
    required this.id,
    required this.number,
    required this.status,
    required this.nextStatus,
    required this.stages,
    required this.priority,
    required this.dueAt,
    required this.isOverdue,
    required this.fulfillment,
    required this.delivery,
    required this.customer,
    required this.lines,
    required this.expressFee,
    required this.total,
    required this.currency,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String number;
  final OrderStatus status;
  final OrderStatus? nextStatus;
  final List<OrderStatus> stages;
  final OrderPriority priority;
  final DateTime? dueAt;
  final bool isOverdue;
  final Fulfillment fulfillment;
  final DeliveryInfo? delivery;
  final OrderCustomer customer;
  final List<OrderLine> lines;
  final int expressFee;
  final int total;
  final String currency;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Order.fromJson(Map<String, dynamic> json) {
    final status = OrderStatus.fromCode(json['status'] as String?);
    final nextCode = json['next_status'] as String?;

    return Order(
      id: json['id'] as int,
      number: json['number'] as String,
      status: status,
      nextStatus: json.containsKey('next_status')
          ? (nextCode == null ? null : OrderStatus.fromCode(nextCode))
          : status.next,
      stages: [
        for (final s in (json['stages'] as List<dynamic>? ?? const []))
          OrderStatus.fromCode(s as String?),
      ],
      priority: OrderPriority.fromCode(json['priority'] as String?),
      dueAt: json['due_at'] == null
          ? null
          : DateTime.parse(json['due_at'] as String).toLocal(),
      isOverdue: json['is_overdue'] as bool? ?? false,
      fulfillment: Fulfillment.fromCode(json['fulfillment'] as String?),
      delivery: json['delivery'] == null
          ? null
          : DeliveryInfo.fromJson(json['delivery'] as Map<String, dynamic>),
      customer:
          OrderCustomer.fromJson(json['customer'] as Map<String, dynamic>),
      lines: (json['lines'] as List<dynamic>? ?? const [])
          .map((e) => OrderLine.fromJson(e as Map<String, dynamic>))
          .toList(),
      expressFee: (json['express_fee'] as num?)?.round() ?? 0,
      total: (json['total'] as num).round(),
      currency: (json['currency'] as String?) ?? 'IDR',
      notes: (json['notes'] as String?) ?? '',
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    );
  }
}