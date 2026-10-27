import '../data/mock_data.dart';
import '../models/order.dart';
import '../models/order_status.dart';
import 'order_repository.dart';

/// Menyimpan pesanan di memori dan meniru perilaku backend.
class MockOrderRepository implements OrderRepository {
  final List<Order> _orders = List.of(mockOrders);

  Future<void> _fakeDelay() =>
      Future.delayed(const Duration(milliseconds: 400));

  @override
  Future<List<Order>> list({OrderStatus? status}) async {
    await _fakeDelay();
    final Iterable<Order> result =
        status == null ? _orders : _orders.where((o) => o.status == status);
    return List.unmodifiable(result);
  }

  @override
  Future<Order> get(int id) async {
    await _fakeDelay();
    return _orders.firstWhere((o) => o.id == id);
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