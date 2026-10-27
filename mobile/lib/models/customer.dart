class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    this.address = '',
  });

  final int id;
  final String name;
  final String phone;
  final String address;

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as int,
      name: json['name'] as String,
      phone: json['phone'] as String,
      address: (json['address'] as String?) ?? '',
    );
  }
}