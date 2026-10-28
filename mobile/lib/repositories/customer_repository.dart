import '../models/customer.dart';

abstract class CustomerRepository {
  Future<List<Customer>> list({String q = ''});

  Future<Customer> create({
    required String name,
    required String phone,
    String address = '',
  });
  
  Future<void> delete(int id);
}

class DuplicateCustomerException implements Exception {
  const DuplicateCustomerException(this.message);

  final String message;

  @override
  String toString() => message;
}