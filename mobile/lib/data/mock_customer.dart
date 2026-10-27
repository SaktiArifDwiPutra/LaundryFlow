import '../models/customer.dart';

final List<Map<String, dynamic>> _mockCustomerJson = [
  {'id': 11, 'name': 'Budi', 'phone': '628111111101', 'address': 'Jl. Mawar 1'},
  {'id': 12, 'name': 'Sari', 'phone': '628111111102', 'address': 'Jl. Melati 2'},
  {'id': 13, 'name': 'Andi', 'phone': '628111111103', 'address': ''},
  {'id': 14, 'name': 'Dewi', 'phone': '628111111104', 'address': 'Jl. Kenanga 4'},
  {'id': 15, 'name': 'Rudi', 'phone': '628111111105', 'address': ''},
  {'id': 16, 'name': 'Maya', 'phone': '628111111106', 'address': 'Jl. Anggrek 6'},
  {'id': 17, 'name': 'Tono', 'phone': '628111111107', 'address': ''},
];

final List<Customer> mockCustomers =
    _mockCustomerJson.map(Customer.fromJson).toList();