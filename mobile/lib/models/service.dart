class Service {
  const Service({
    required this.id,
    required this.name,
    required this.unit,
    required this.unitPrice,
    this.currency = 'IDR',
    this.needsWash = true,
    this.needsDry = true,
    this.needsIron = true,
  });

  final int id;
  final String name;
  final String unit;
  final int unitPrice;
  final String currency;
  final bool needsWash;
  final bool needsDry;
  final bool needsIron;

  factory Service.fromJson(Map<String, dynamic> json) {
    return Service(
      id: json['id'] as int,
      name: json['name'] as String,
      unit: ((json['uom'] ?? json['unit']) as String?) ?? '',
      unitPrice: (json['unit_price'] as num).round(),
      currency: (json['currency'] as String?) ?? 'IDR',
      needsWash: json['needs_wash'] as bool? ?? true,
      needsDry: json['needs_dry'] as bool? ?? true,
      needsIron: json['needs_iron'] as bool? ?? true,
    );
  }
}