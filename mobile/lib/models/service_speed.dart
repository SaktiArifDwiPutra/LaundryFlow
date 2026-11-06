/// Pilihan kecepatan pengerjaan: `regular` atau `same_day`
/// (GET /api/laundry/service-speeds).
class ServiceSpeed {
  const ServiceSpeed({
    required this.code,
    required this.name,
    required this.available,
    required this.fee,
    this.description = '',
  });

  final String code;
  final String name;
  final bool available;

  /// Biaya tambahan. 0 berarti belum ada tarif yang dikonfirmasi di Odoo.
  final int fee;
  final String description;

  bool get isSameDay => code == 'same_day';

  factory ServiceSpeed.fromJson(Map<String, dynamic> json) {
    final code = json['code'] as String;
    return ServiceSpeed(
      code: code,
      name: (json['name'] as String?) ?? code,
      available: json['available'] as bool? ?? true,
      fee: (json['fee'] as num?)?.round() ?? 0,
      description: (json['description'] as String?) ?? '',
    );
  }
}