import '../models/order.dart';

Map<String, dynamic> _order({
  required int id,
  required String status,
  required String customer,
  required String phone,
  required String service,
  required double qty,
  required int unitPrice,
  String unit = 'kg',
  String notes = '',
}) {
  final subtotal = (qty * unitPrice).round();
  return {
    'id': id,
    'number': 'LF-2026-${id.toString().padLeft(4, '0')}',
    'status': status,
    'customer': {'id': id + 10, 'name': customer, 'phone': phone},
    'lines': [
      {
        'service_id': 3,
        'service_name': service,
        'qty': qty,
        'unit': unit,
        'unit_price': unitPrice,
        'subtotal': subtotal,
      },
    ],
    'total': subtotal,
    'currency': 'IDR',
    'notes': notes,
    'created_at': '2026-10-26T02:15:00Z',
    'updated_at': '2026-10-26T03:00:00Z',
  };
}

final List<Map<String, dynamic>> _mockOrderJson = [
  _order(
    id: 1,
    status: 'received',
    customer: 'Budi',
    phone: '628111111101',
    service: 'Cuci Kiloan',
    qty: 3.5,
    unitPrice: 8000,
  ),
  _order(
    id: 2,
    status: 'washing',
    customer: 'Sari',
    phone: '628111111102',
    service: 'Cuci Kiloan',
    qty: 5,
    unitPrice: 8000,
    notes: 'Pisahkan putih',
  ),
  _order(
    id: 3,
    status: 'drying',
    customer: 'Andi',
    phone: '628111111103',
    service: 'Cuci Setrika',
    qty: 2,
    unitPrice: 10000,
  ),
  _order(
    id: 4,
    status: 'ironing',
    customer: 'Dewi',
    phone: '628111111104',
    service: 'Cuci Setrika',
    qty: 4,
    unitPrice: 10000,
  ),
  _order(
    id: 5,
    status: 'ready',
    customer: 'Rudi',
    phone: '628111111105',
    service: 'Cuci Kiloan',
    qty: 6,
    unitPrice: 8000,
  ),
  _order(
    id: 6,
    status: 'completed',
    customer: 'Maya',
    phone: '628111111106',
    service: 'Selimut',
    qty: 1,
    unit: 'pcs',
    unitPrice: 25000,
  ),
  _order(
    id: 7,
    status: 'packing',
    customer: 'Tono',
    phone: '628111111107',
    service: 'Cuci Kiloan',
    qty: 2,
    unitPrice: 8000,
  ),
];

final List<Order> mockOrders = _mockOrderJson.map(Order.fromJson).toList();
