class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    this.email = '',
    this.street = '',
    this.city = '',
    this.rawAddress,
  });

  final int id;
  final String name;
  final String phone;
  final String email;
  final String street;
  final String city;
  final String? rawAddress;

  String get address {
    if (rawAddress != null && rawAddress!.isNotEmpty) {
      return rawAddress!;
    }
    return [street, city].where((s) => s.isNotEmpty).join(', ');
  }

  factory Customer.fromJson(Map<String, dynamic> json) {
    final addr = (json['address'] as String?) ?? '';
    return Customer(
      id: json['id'] as int,
      name: (json['name'] as String?) ?? '',
      phone: (json['phone'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      street: (json['street'] as String?) ?? '',
      city: (json['city'] as String?) ?? '',
      rawAddress: addr.isNotEmpty ? addr : null,
    );
  }
}