enum OrderStatus {
  received('received', 'Diterima'),
  washing('washing', 'Dicuci'),
  drying('drying', 'Dikeringkan'),
  ironing('ironing', 'Disetrika'),
  ready('ready', 'Siap Diambil'),
  completed('completed', 'Selesai'),
  unknown('unknown', 'Tidak dikenal');

  const OrderStatus(this.code, this.label);
  final String code;
  final String label;

  OrderStatus? get next => switch (this) {
        OrderStatus.received => OrderStatus.washing,
        OrderStatus.washing => OrderStatus.drying,
        OrderStatus.drying => OrderStatus.ironing,
        OrderStatus.ironing => OrderStatus.ready,
        OrderStatus.ready => OrderStatus.completed,
        OrderStatus.completed || OrderStatus.unknown => null,
      };

  static OrderStatus fromCode(String? code) {
    return OrderStatus.values.firstWhere(
      (s) => s.code == code,
      orElse: () => OrderStatus.unknown,
    );
  }
}