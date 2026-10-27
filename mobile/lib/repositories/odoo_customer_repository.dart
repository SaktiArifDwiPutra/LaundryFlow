import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../models/customer.dart';
import 'customer_repository.dart';

/// Pencarian lewat GET /api/laundry/customers/search (lihat docs/api).
class OdooCustomerRepository implements CustomerRepository {
  OdooCustomerRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<Customer>> list({String q = ''}) async {
    final query = q.trim();
    if (query.isEmpty) return const []; // backend menolak kata kunci kosong
    final json = await _api.get(
      '/api/laundry/customers/search',
      query: {'q': query, 'limit': '20'},
    );
    final data = json['data'] as List<dynamic>? ?? const [];
    return [
      for (final item in data)
        Customer.fromJson(item as Map<String, dynamic>),
    ];
  }

  @override
  Future<Customer> create({
    required String name,
    required String phone,
    String address = '',
  }) async {
    throw const ApiException('Tambah pelanggan belum tersedia di backend.');
  }
}