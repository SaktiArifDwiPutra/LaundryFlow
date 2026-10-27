import '../data/mock_data.dart';
import '../models/customer.dart';
import '../models/order.dart';
import '../models/order_status.dart';
import 'order_repository.dart';
class MockOrderRepository implements OrderRepository {
  final List<Order> _orders = List.of(mockOrders);
  int _nextId = 100;

  Future<void> _fakeDelay() =>
      Future.delayed(const Duration(milliseconds: 400));

  @override
  Future<List<Order>> list({OrderStatus? status, String q = ''}) async {
    await _fakeDelay();
    final query = q.toLowerCase();
    final result = _orders.where((o) {
      if (status != null && o.status != status) return false;
      if (query.isEmpty) return true;
      return o.customer.name.toLowerCase().contains(query) ||
          o.customer.phone.contains(query) ||
          o.number.toLowerCase().contains(query);
    });
    return List.unmodifiable(result);
  }

  @override
  Future<Order> get(int id) async {
    await _fakeDelay();
    return _orders.firstWhere((o) => o.id == id);
  }

  @override
  Future<Order> create({
    required Customer customer,
    required List<OrderLineInput> lines,
    String notes = '',
  }) async {
    await _fakeDelay();
    if (lines.isEmpty) {
      throw StateError('Pesanan harus punya minimal satu layanan');
    }

    final orderLines = [
      for (final l in lines)
        OrderLine(
          serviceId: l.service.id,
          serviceName: l.service.name,
          qty: l.qty,
          unit: l.service.unit,
          unitPrice: l.service.unitPrice,
          subtotal: (l.qty * l.service.unitPrice).round(),
        ),
    ];
    final total = orderLines.fold<int>(0, (sum, l) => sum + l.subtotal);

    final id = _nextId++;
    final now = DateTime.now();
    final order = Order(
      id: id,
      number: 'LF-${now.year}-${id.toString().padLeft(4, '0')}',
      status: OrderStatus.received,
      customer: OrderCustomer(
        id: customer.id,
        name: customer.name,
        phone: customer.phone,
      ),
      lines: orderLines,
      total: total,
      currency: 'IDR',
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
    _orders.insert(0, order);
    return order;
  }

  @override
  Future<Order> advanceStatus(int id, OrderStatus to) async {
    await _fakeDelay();
    final index = _orders.indexWhere((o) => o.id == id);
    if (index == -1) throw StateError('Pesanan $id tidak ditemukan');

    final current = _orders[index];
    if (current.status.next != to) {
      throw const InvalidTransitionException('Status tidak boleh dilompati.');
    }

    final updated = current.copyWith(status: to, updatedAt: DateTime.now());
    _orders[index] = updated;
    return updated;
  }
}