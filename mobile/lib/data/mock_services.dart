import '../models/service.dart';

final List<Map<String, dynamic>> _mockServiceJson = [
  {'id': 3, 'name': 'Cuci Kiloan', 'unit': 'kg', 'unit_price': 8000, 'currency': 'IDR'},
  {'id': 4, 'name': 'Cuci Setrika', 'unit': 'kg', 'unit_price': 10000, 'currency': 'IDR'},
  {'id': 5, 'name': 'Setrika Saja', 'unit': 'kg', 'unit_price': 6000, 'currency': 'IDR'},
  {'id': 6, 'name': 'Selimut', 'unit': 'pcs', 'unit_price': 25000, 'currency': 'IDR'},
];

final List<Service> mockServices =
    _mockServiceJson.map(Service.fromJson).toList();