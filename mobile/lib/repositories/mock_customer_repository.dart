import '../data/mock_customers.dart';
import '../models/customer.dart';
import 'customer_repository.dart';

class MockCustomerRepository implements CustomerRepository {
  final List<Customer> _customers = List.of(mockCustomers);
  int _nextId = 100;

  Future<void> _fakeDelay() =>
      Future.delayed(const Duration(milliseconds: 400));

  @override
  Future<List<Customer>> list({String q = ''}) async {
    await _fakeDelay();
    final query = q.trim().toLowerCase();
    if (query.isEmpty) return const [];

    final result = _customers
        .where(
          (c) =>
              c.name.toLowerCase().contains(query) || c.phone.contains(query),
        )
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return result.take(20).toList(); // limit bawaan backend
  }

  @override
  Future<Customer> create({
    required String name,
    required String phone,
    String address = '',
  }) async {
    await _fakeDelay();
    final dup = _customers.where((c) => c.phone == phone);
    if (dup.isNotEmpty) {
      throw DuplicateCustomerException(
        'Nomor $phone sudah terdaftar atas nama ${dup.first.name}.',
      );
    }
    final customer = Customer(
      id: _nextId++,
      name: name,
      phone: phone,
      street: address,
    );
    _customers.add(customer);
    return customer;
  }

  @override
  Future<void> delete(int id) async {
    await _fakeDelay();
    _customers.removeWhere((c) => c.id == id);
  }
}