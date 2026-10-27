import '../models/customer.dart';

final List<Map<String, dynamic>> _mockCustomerJson = [
  {'id': 11, 'name': 'Budi', 'phone': '628111111101', 'email': '', 'street': 'Jl. Mawar 1', 'city': 'Bandung'},
  {'id': 12, 'name': 'Sari', 'phone': '0811-1111-1102', 'email': 'sari@contoh.id', 'street': 'Jl. Melati 2', 'city': 'Bandung'},
  {'id': 13, 'name': 'Andi', 'phone': '628111111103', 'email': '', 'street': '', 'city': ''},
  {'id': 14, 'name': 'Dewi', 'phone': '+62 811 1111 1104', 'email': '', 'street': 'Jl. Kenanga 4', 'city': 'Cimahi'},
  {'id': 15, 'name': 'Rudi', 'phone': '628111111105', 'email': '', 'street': '', 'city': ''},
  {'id': 16, 'name': 'Maya', 'phone': '628111111106', 'email': '', 'street': 'Jl. Anggrek 6', 'city': 'Bandung'},
  {'id': 17, 'name': 'Tono', 'phone': '', 'email': '', 'street': '', 'city': ''},
];

final List<Customer> mockCustomers =
    _mockCustomerJson.map(Customer.fromJson).toList();