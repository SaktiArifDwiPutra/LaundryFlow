enum OrderPriority {
  regular('regular', 'Reguler'),
  express('express', 'Express');

  const OrderPriority(this.code, this.label);

  final String code;
  final String label;

  static OrderPriority fromCode(String? code) {
    return OrderPriority.values.firstWhere(
      (p) => p.code == code,
      orElse: () => OrderPriority.regular,
    );
  }
}

enum Fulfillment {
  pickup('pickup', 'Ambil sendiri'),
  delivery('delivery', 'Diantar');

  const Fulfillment(this.code, this.label);

  final String code;
  final String label;

  static Fulfillment fromCode(String? code) {
    return Fulfillment.values.firstWhere(
      (f) => f.code == code,
      orElse: () => Fulfillment.pickup,
    );
  }
}