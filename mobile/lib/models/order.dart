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
    this.itemDetails = '',
  });

  final int serviceId;
  final String serviceName;
  final double qty;
  final String unit;
  final int unitPrice;
  final int subtotal;
  final String itemDetails;

  factory OrderLine.fromJson(Map<String, dynamic> json) {
    final qtyVal = (json['quantity'] ?? json['qty'] ?? json['weight'] ?? 1.0) as num;
    return OrderLine(
      serviceId: ((json['product_id'] ?? json['service_id'] ?? json['product_template_id']) as int?) ?? 0,
      serviceName: ((json['product_name'] ?? json['service_name'] ?? json['name']) as String?) ?? 'Layanan',
      qty: qtyVal.toDouble(),
      unit: ((json['uom'] ?? json['unit']) as String?) ?? '',
      unitPrice: ((json['price_unit'] ?? json['unit_price'] ?? 0) as num).round(),
      subtotal: ((json['subtotal'] ?? 0) as num).round(),
      itemDetails: (json['item_details'] as String?) ?? '',
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
      address: ((json['address'] ?? json['delivery_address']) as String?) ?? '',
      fee: ((json['fee'] ?? json['delivery_fee'] ?? 0) as num).round(),
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
    this.paymentStatus = 'unpaid',
    this.paymentMethod = '',
    this.amountPaid = 0,
    this.amountDue = 0,
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
  final String paymentStatus;
  final String paymentMethod;
  final int amountPaid;
  final int amountDue;

  bool get isPaid => paymentStatus == 'paid';
  bool get isPartial => paymentStatus == 'partial';
  bool get isUnpaid => paymentStatus == 'unpaid' || paymentStatus.isEmpty;
  bool get isExpress => priority == OrderPriority.express;

  String get paymentLabel => switch (paymentStatus) {
        'paid' => 'Lunas',
        'partial' => 'Sebagian',
        _ => 'Belum Lunas',
      };

  Order copyWith({
    int? id,
    String? number,
    OrderStatus? status,
    OrderStatus? nextStatus,
    List<OrderStatus>? stages,
    OrderPriority? priority,
    DateTime? dueAt,
    bool? isOverdue,
    Fulfillment? fulfillment,
    DeliveryInfo? delivery,
    OrderCustomer? customer,
    List<OrderLine>? lines,
    int? expressFee,
    int? total,
    String? currency,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? paymentStatus,
    String? paymentMethod,
    int? amountPaid,
    int? amountDue,
  }) {
    return Order(
      id: id ?? this.id,
      number: number ?? this.number,
      status: status ?? this.status,
      nextStatus: nextStatus ?? this.nextStatus,
      stages: stages ?? this.stages,
      priority: priority ?? this.priority,
      dueAt: dueAt ?? this.dueAt,
      isOverdue: isOverdue ?? this.isOverdue,
      fulfillment: fulfillment ?? this.fulfillment,
      delivery: delivery ?? this.delivery,
      customer: customer ?? this.customer,
      lines: lines ?? this.lines,
      expressFee: expressFee ?? this.expressFee,
      total: total ?? this.total,
      currency: currency ?? this.currency,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      amountPaid: amountPaid ?? this.amountPaid,
      amountDue: amountDue ?? this.amountDue,
    );
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    final status = OrderStatus.fromCode((json['state'] ?? json['status']) as String?);
    final nextCode = (json['next_status'] ?? json['next_state']) as String?;

    final customerRaw = json['customer'];
    final customer = customerRaw is Map<String, dynamic>
        ? OrderCustomer.fromJson(customerRaw)
        : OrderCustomer(
            id: (json['partner_id'] as int?) ?? 0,
            name: (json['partner_name'] as String?) ?? 'Pelanggan',
            phone: ((json['partner_phone'] ?? json['phone']) as String?) ?? '',
          );

    final rawStages = json['stages'] as List<dynamic>?;
    final List<OrderStatus> stages;
    if (rawStages != null && rawStages.isNotEmpty) {
      stages = [for (final s in rawStages) OrderStatus.fromCode(s as String?)];
    } else {
      stages = const [
        OrderStatus.received,
        OrderStatus.washing,
        OrderStatus.drying,
        OrderStatus.ironing,
        OrderStatus.ready,
        OrderStatus.completed,
      ];
    }

    final dateStr = (json['order_date'] ?? json['created_at']) as String?;
    final createdAt = dateStr != null
        ? DateTime.tryParse(dateStr)?.toLocal() ?? DateTime.now()
        : DateTime.now();

    final updateStr = json['updated_at'] as String?;
    final updatedAt = updateStr != null
        ? DateTime.tryParse(updateStr)?.toLocal() ?? createdAt
        : createdAt;

    final dueStr = json['due_at'] as String?;
    final dueAt = dueStr != null ? DateTime.tryParse(dueStr)?.toLocal() : null;

    final isOverdue = json['is_overdue'] as bool? ??
        (dueAt != null && DateTime.now().isAfter(dueAt) && status != OrderStatus.completed);

    return Order(
      id: json['id'] as int,
      number: ((json['name'] ?? json['number']) as String?) ?? 'LF-${json['id']}',
      status: status,
      nextStatus: json.containsKey('next_status')
          ? (nextCode == null ? null : OrderStatus.fromCode(nextCode))
          : status.next,
      stages: stages,
      priority: OrderPriority.fromCode((json['service_speed'] ?? json['priority']) as String?),
      dueAt: dueAt,
      isOverdue: isOverdue,
      fulfillment: Fulfillment.fromCode(
          (json['delivery_type'] ?? json['fulfillment']) as String?),
      delivery: json['delivery'] != null
          ? DeliveryInfo.fromJson(json['delivery'] as Map<String, dynamic>)
          : ((json['delivery_type'] == 'delivery' ||
                  ((json['delivery_fee'] ?? 0) as num) > 0 ||
                  ((json['delivery_address'] as String?)?.trim().isNotEmpty == true))
              ? DeliveryInfo(
                  address: ((json['delivery_address'] ?? json['address']) as String?) ?? '',
                  fee: ((json['delivery_fee'] ?? json['fee'] ?? 0) as num).round(),
                )
              : null),
      customer: customer,
      lines: (json['lines'] as List<dynamic>? ?? const [])
          .map((e) => OrderLine.fromJson(e as Map<String, dynamic>))
          .toList(),
      expressFee: ((json['service_speed_fee'] ?? json['express_fee'] ?? 0) as num).round(),
      total: ((json['total_amount'] ?? json['total'] ?? 0) as num).round(),
      currency: (json['currency'] as String?) ?? 'IDR',
      notes: (json['notes'] as String?) ?? '',
      createdAt: createdAt,
      updatedAt: updatedAt,
      paymentStatus: (json['payment_status'] as String?) ?? 'unpaid',
      paymentMethod: (json['payment_method'] as String?) ?? '',
      amountPaid: ((json['amount_paid'] ?? 0) as num).round(),
      amountDue: ((json['amount_due'] ?? (json['total_amount'] ?? json['total'] ?? 0)) as num).round(),
    );
  }
}