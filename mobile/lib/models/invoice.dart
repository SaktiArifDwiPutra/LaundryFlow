class Invoice {
  const Invoice({
    required this.id,
    required this.number,
    required this.state,
    required this.paymentState,
    required this.total,
    required this.currency,
  });

  final int id;
  final String number;

  /// Nilai mentah dari backend. Daftar nilai yang sebenarnya belum dikonfirmasi.
  final String state;
  final String paymentState;
  final int total;
  final String currency;

  bool get isPaid => paymentState == 'paid';

  String get stateLabel => switch (state) {
        'draft' => 'Draf',
        'posted' => 'Terbit',
        'cancel' => 'Dibatalkan',
        _ => state.isEmpty ? '-' : state,
      };

  String get paymentLabel => switch (paymentState) {
        'paid' => 'Lunas',
        'not_paid' => 'Belum dibayar',
        'partial' => 'Dibayar sebagian',
        'in_payment' => 'Sedang diproses',
        'reversed' => 'Dibatalkan',
        _ => paymentState.isEmpty ? '-' : paymentState,
      };

  /// Bentuk sama dengan GET /orders/{id}/invoice di catatan API.
  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: json['id'] as int,
      number: (json['number'] as String?) ?? '',
      state: (json['state'] as String?) ?? '',
      paymentState: (json['payment_state'] as String?) ?? '',
      total: json['total'] as int,
      currency: (json['currency'] as String?) ?? 'IDR',
    );
  }
}