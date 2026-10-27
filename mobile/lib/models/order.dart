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
      phone: json['phone'] as String,
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
      serviceId: json['service_id'] as int,
      serviceName: json['service_name'] as String,
      qty: (json['qty'] as num).toDouble(),
      unit: json['unit'] as String,
      unitPrice: json['unit_price'] as int,
      subtotal: json['subtotal'] as int,
    );
  }
}

class Order {
  const Order({
    required this.id,
    required this.number,
    required this.status,
    required this.customer,
    required this.lines,
    required this.total,
    required this.currency,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String number;
  final OrderStatus status;
  final OrderCustomer customer;
  final List<OrderLine> lines;
  final int total;
  final String currency;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Order copyWith({OrderStatus? status, DateTime? updatedAt}) {
    return Order(
      id: id,
      number: number,
      status: status ?? this.status,
      customer: customer,
      lines: lines,
      total: total,
      currency: currency,
      notes: notes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as int,
      number: json['number'] as String,
      status: OrderStatus.fromCode(json['status'] as String?),
      customer: OrderCustomer.fromJson(
        json['customer'] as Map<String, dynamic>,
      ),
      lines: (json['lines'] as List<dynamic>)
          .map((e) => OrderLine.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int,
      currency: json['currency'] as String,
      notes: (json['notes'] as String?) ?? '',
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    );
  }
}
