import '../api/api_client.dart';
import '../models/service.dart';
import '../models/service_speed.dart';
import 'service_repository.dart';

/// GET /api/laundry/products dan GET /api/laundry/service-speeds (lihat spesifikasi).
class OdooServiceRepository implements ServiceRepository {
  OdooServiceRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<Service>> list() async {
    final json = await _api.get('/api/laundry/products');
    final data = json['data'] as List<dynamic>? ?? const [];
    return [
      for (final item in data) Service.fromJson(item as Map<String, dynamic>),
    ];
  }

  @override
  Future<List<ServiceSpeed>> speeds() async {
    final json = await _api.get('/api/laundry/service-speeds');
    final data = json['data'] as List<dynamic>? ?? const [];
    return [
      for (final item in data)
        ServiceSpeed.fromJson(item as Map<String, dynamic>),
    ];
  }
}