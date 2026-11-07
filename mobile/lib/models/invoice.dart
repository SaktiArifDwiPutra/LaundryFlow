class Invoice {
  const Invoice({
    required this.id,
    required this.number,
    required this.state,
    required this.paymentState,
    required this.total,
    this.orderId = 0,
    this.orderNumber = '',
    this.amountPaid = 0,
    this.amountDue = 0,
    this.changeAmount = 0,
    this.paymentMethod = '',
    this.paymentDate,
    this.paymentReference,
    this.currency = 'IDR',
  });

  final int id;
  final String number;
  final String state;
  final String paymentState;
  final int total;
  final int orderId;
  final String orderNumber;
  final int amountPaid;
  final int amountDue;
  final int changeAmount;
  final String paymentMethod;
  final String? paymentDate;
  final String? paymentReference;
  final String currency;

  bool get isPaid => paymentState == 'paid';
  bool get isPartial => paymentState == 'partial';
  bool get isUnpaid =>
      paymentState == 'unpaid' ||
      paymentState == 'not_paid' ||
      paymentState.isEmpty;

  String get stateLabel => switch (state) {
        'draft' => 'Draf',
        'posted' => 'Terbit',
        'cancel' => 'Dibatalkan',
        _ => state.isEmpty ? '-' : state,
      };

  String get paymentLabel => switch (paymentState) {
        'paid' => 'Lunas',
        'unpaid' || 'not_paid' => 'Belum dibayar',
        'partial' => 'Dibayar sebagian',
        'in_payment' => 'Sedang diproses',
        'reversed' => 'Dibatalkan',
        _ => paymentState.isEmpty ? 'Belum dibayar' : paymentState,
      };

  String get methodLabel => switch (paymentMethod.toLowerCase()) {
        'cash' => 'Tunai',
        'qris' => 'QRIS',
        'transfer' => 'Transfer',
        _ => paymentMethod.isEmpty ? '-' : paymentMethod,
      };

  factory Invoice.fromJson(Map<String, dynamic> json) {
    final status = (json['payment_status'] ?? json['payment_state']) as String?;
    return Invoice(
      id: (json['order_id'] ?? json['id'] ?? 0) as int,
      number: (json['invoice_number'] ?? json['number'] ?? '') as String,
      orderId: (json['order_id'] ?? json['id'] ?? 0) as int,
      orderNumber: (json['order_number'] ?? '') as String,
      state: (json['state'] as String?) ?? 'posted',
      paymentState: status ?? 'unpaid',
      total: ((json['total_amount'] ?? json['total'] ?? 0) as num).round(),
      amountPaid: ((json['amount_paid'] ?? 0) as num).round(),
      amountDue: ((json['amount_due'] ?? 0) as num).round(),
      changeAmount: ((json['change_amount'] ?? 0) as num).round(),
      paymentMethod: (json['payment_method'] as String?) ?? '',
      paymentDate: json['payment_date'] as String?,
      paymentReference: json['payment_reference'] as String?,
      currency: (json['currency'] as String?) ?? 'IDR',
    );
  }
}
