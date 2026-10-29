import '../api/api_client.dart';
import '../models/service.dart';
import 'service_repository.dart';

class OdooServiceRepository implements ServiceRepository {
  OdooServiceRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<Service>> list() async {
    final json = await _api.get(
      '/api/laundry/products',
      query: {'limit': '100'},
    );
    final data = json['data'] as List<dynamic>? ?? const [];
    return [
      for (final item in data) Service.fromJson(item as Map<String, dynamic>),
    ];
  }
}