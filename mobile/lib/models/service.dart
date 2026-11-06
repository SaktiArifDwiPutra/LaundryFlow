/// Cara menghitung harga satu layanan (dari `pricing_type` backend).
enum PricingType {
  weight('weight'), // per kg: field `weight`
  unit('unit'), // per pcs / set: field `quantity`
  area('area'); // karpet: `length` x `width` (m²)

  const PricingType(this.code);

  final String code;

  /// Kalau backend tidak mengirim pricing_type, tebak dari satuannya.
  static PricingType resolve(String? code, String uom) {
    for (final t in PricingType.values) {
      if (t.code == code) return t;
    }
    final u = uom.trim().toLowerCase();
    if (u == 'kg') return PricingType.weight;
    if (u == 'm²' || u == 'm2') return PricingType.area;
    return PricingType.unit;
  }
}

class Service {
  const Service({
    required this.id,
    required this.name,
    required this.unit,
    required this.unitPrice,
    this.pricingType = PricingType.unit,
    this.sku = '',
    this.category = '',
    this.currency = 'IDR',
    this.needsWash = true,
    this.needsDry = true,
    this.needsIron = true,
  });

  final int id;
  final String name;
  final String unit;
  final int unitPrice;
  final PricingType pricingType;
  final String sku;
  final String category;
  final String currency;

  /// Hanya dipakai "server palsu" untuk menyusun jalur status di mode mock.
  /// Backend sungguhan menentukan jalurnya sendiri.
  final bool needsWash;
  final bool needsDry;
  final bool needsIron;

  /// Bentuk item `data` pada GET /api/laundry/products.
  factory Service.fromJson(Map<String, dynamic> json) {
    final unit = ((json['uom'] ?? json['unit']) as String?) ?? '';
    return Service(
      id: json['id'] as int,
      name: json['name'] as String,
      unit: unit,
      unitPrice: (json['unit_price'] as num).round(),
      pricingType: PricingType.resolve(json['pricing_type'] as String?, unit),
      sku: (json['sku'] as String?) ?? '',
      category: (json['category'] as String?) ?? '',
      currency: (json['currency'] as String?) ?? 'IDR',
      needsWash: json['needs_wash'] as bool? ?? true,
      needsDry: json['needs_dry'] as bool? ?? true,
      needsIron: json['needs_iron'] as bool? ?? true,
    );
  }
}