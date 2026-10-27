import '../data/mock_customer.dart';
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
    final query = q.toLowerCase();
    final result = _customers.where(
      (c) => query.isEmpty ||
          c.name.toLowerCase().contains(query) ||
          c.phone.contains(query),
    ).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return result;
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
      address: address,
    );
    _customers.add(customer);
    return customer;
  }
}