class Service {
  const Service({
    required this.id,
    required this.name,
    required this.unit,
    required this.unitPrice,
    this.currency = 'IDR',
  });

  final int id;
  final String name;
  final String unit;
  final int unitPrice;
  final String currency;

  factory Service.fromJson(Map<String, dynamic> json) {
    return Service(
      id: json['id'] as int,
      name: json['name'] as String,
      unit: json['unit'] as String,
      unitPrice: json['unit_price'] as int,
      currency: (json['currency'] as String?) ?? 'IDR',
    );
  }
}