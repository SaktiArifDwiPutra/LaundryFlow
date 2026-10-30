import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../models/customer.dart';
import 'customer_repository.dart';
class OdooCustomerRepository implements CustomerRepository {
  OdooCustomerRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<Customer>> list({String q = ''}) async {
    final query = q.trim();
    if (query.isEmpty) return const [];
    final Map<String, dynamic> json;
    try {
      json = await _api.get(
        '/api/laundry/customers/search',
        query: {'q': query, 'limit': '20'},
      );
    } on ApiException catch (e) {
      if (e.statusCode == 404) return const [];
      rethrow;
    }
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
    final json = await _api.post(
      '/api/laundry/customers',
      body: {
        'name': name.trim(),
        'phone': phone.trim(),
        if (address.trim().isNotEmpty) 'street': address.trim(),
      },
    );
    final data = json['data'];
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Respons server tidak valid.');
    }
    return Customer.fromJson(data);
  }

  @override
  Future<void> delete(int id) async {
    await _api.delete('/api/laundry/customers/$id');
  }
  
}