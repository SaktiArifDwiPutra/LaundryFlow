import '../models/service.dart';
import 'mock_services.dart';

Map<String, dynamic> lineSnapshot(Service s, double qty) => {
      'product_id': s.id,
      'product_name': s.name,
      'uom': s.unit,
      'unit_price': s.unitPrice,
      'qty': qty,
      'needs_wash': s.needsWash,
      'needs_dry': s.needsDry,
      'needs_iron': s.needsIron,
    };

List<Map<String, dynamic>> buildMockOrderJson() {
  final now = DateTime.now().toUtc();
  String at(int hours) => now.add(Duration(hours: hours)).toIso8601String();
  Service svc(int id) => mockServices.firstWhere((s) => s.id == id);

  Map<String, dynamic> seed({
    required int id,
    required String status,
    required int customerId,
    required String customer,
    required String phone,
    required List<(int, double)> lines,
    required int createdAgo,
    required int dueIn,
    String priority = 'regular',
    String fulfillment = 'pickup',
    String address = '',
    int fee = 0,
    String notes = '',
  }) =>
      {
        'id': id,
        'number': 'LF-2026-${id.toString().padLeft(4, '0')}',
        'status': status,
        'priority': priority,
        'fulfillment': fulfillment,
        'delivery':
            fulfillment == 'delivery' ? {'address': address, 'fee': fee} : null,
        'customer': {'id': customerId, 'name': customer, 'phone': phone},
        'lines': [
          for (final (productId, qty) in lines) lineSnapshot(svc(productId), qty),
        ],
        'notes': notes,
        'due_at': at(dueIn),
        'created_at': at(-createdAgo),
        'updated_at': at(-1),
      };

  return [
    seed(id: 1, status: 'received', customerId: 11, customer: 'Budi', phone: '628111111101', lines: [(3, 3.5)], createdAgo: 2, dueIn: 46),
    seed(id: 2, status: 'washing', customerId: 12, customer: 'Sari', phone: '081111111102', lines: [(4, 5.0)], priority: 'express', fulfillment: 'delivery', address: 'Jl. Melati 2, Bandung', fee: 5000, notes: 'Pisahkan putih', createdAgo: 5, dueIn: 19),
    seed(id: 3, status: 'drying', customerId: 13, customer: 'Andi', phone: '628111111103', lines: [(4, 2.0)], createdAgo: 28, dueIn: 20),
    seed(id: 4, status: 'ironing', customerId: 14, customer: 'Dewi', phone: '+62 811 1111 1104', lines: [(5, 4.0)], createdAgo: 52, dueIn: -4),
    seed(id: 5, status: 'ready', customerId: 15, customer: 'Rudi', phone: '628111111105', lines: [(3, 6.0)], createdAgo: 30, dueIn: 18),
    seed(id: 6, status: 'completed', customerId: 16, customer: 'Maya', phone: '628111111106', lines: [(6, 1.0)], createdAgo: 90, dueIn: -42),
    seed(id: 7, status: 'packing', customerId: 17, customer: 'Tono', phone: '', lines: [(3, 2.0)], createdAgo: 10, dueIn: 38),
    seed(id: 8, status: 'out_for_delivery', customerId: 18, customer: 'Lina', phone: '628111111108', lines: [(4, 3.0)], priority: 'express', fulfillment: 'delivery', address: 'Jl. Kenanga 4, Cimahi', fee: 5000, createdAgo: 20, dueIn: 4),
    seed(id: 9, status: 'received', customerId: 19, customer: 'Joko', phone: '628111111109', lines: [(5, 2.0)], priority: 'express', createdAgo: 1, dueIn: 23),
    seed(id: 10, status: 'washing', customerId: 20, customer: 'Nina', phone: '628111111110', lines: [(3, 2.0), (5, 1.0)], createdAgo: 3, dueIn: 45),
  ];
}