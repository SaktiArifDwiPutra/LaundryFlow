import '../models/service.dart';
import '../models/service_speed.dart';

/// Layanan contoh, bentuknya mengikuti GET /api/laundry/products.
/// Harga dan penanda needs_* hanya karangan untuk mock.
final List<Map<String, dynamic>> _mockServiceJson = [
  {'id': 3, 'name': 'Cuci Lipat', 'uom': 'kg', 'unit_price': 7000, 'pricing_type': 'weight', 'needs_wash': true, 'needs_dry': true, 'needs_iron': false},
  {'id': 4, 'name': 'Cuci Setrika', 'uom': 'kg', 'unit_price': 9000, 'pricing_type': 'weight', 'needs_wash': true, 'needs_dry': true, 'needs_iron': true},
  {'id': 5, 'name': 'Setrika Saja', 'uom': 'kg', 'unit_price': 6000, 'pricing_type': 'weight', 'needs_wash': false, 'needs_dry': false, 'needs_iron': true},
  {'id': 6, 'name': 'Selimut', 'uom': 'pcs', 'unit_price': 25000, 'pricing_type': 'unit', 'needs_wash': true, 'needs_dry': true, 'needs_iron': false},
  {'id': 7, 'name': 'Cuci Satuan', 'uom': 'pcs', 'unit_price': 25000, 'pricing_type': 'unit', 'needs_wash': true, 'needs_dry': false, 'needs_iron': true},
  {'id': 8, 'name': 'Dry Cleaning', 'uom': 'pcs', 'unit_price': 35000, 'pricing_type': 'unit', 'needs_wash': true, 'needs_dry': false, 'needs_iron': true},
  {'id': 9, 'name': 'Karpet', 'uom': 'm²', 'unit_price': 20000, 'pricing_type': 'area', 'needs_wash': true, 'needs_dry': true, 'needs_iron': false},
];

final List<Service> mockServices =
    _mockServiceJson.map(Service.fromJson).toList();

/// Bentuk mengikuti GET /api/laundry/service-speeds.
final List<Map<String, dynamic>> _mockSpeedJson = [
  {'code': 'regular', 'name': 'Reguler', 'available': true, 'fee': 0, 'description': 'Pengerjaan standar sesuai antrean'},
  {'code': 'same_day', 'name': 'Same Day Service', 'available': true, 'fee': 0, 'description': 'Pengerjaan prioritas selesai di hari yang sama'},
];

final List<ServiceSpeed> mockServiceSpeeds =
    _mockSpeedJson.map(ServiceSpeed.fromJson).toList();