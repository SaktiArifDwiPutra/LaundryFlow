import '../models/invoice.dart';
import '../models/order_status.dart';
import 'invoice_repository.dart';
import 'order_repository.dart';

/// Meniru GET /orders/{id}/invoice. Kapan invoice dibuat belum dikonfirmasi
/// backend; di mock: ada saat pesanan "ready" (belum dibayar) dan
/// "completed" (lunas).
class MockInvoiceRepository implements InvoiceRepository {
  MockInvoiceRepository(this._orders);

  final OrderRepository _orders;

  @override
  Future<Invoice?> getForOrder(int orderId) async {
    final order = await _orders.get(orderId);
    final status = order.status;
    if (status != OrderStatus.ready && status != OrderStatus.completed) {
      return null;
    }
    return Invoice.fromJson({
      'id': 5000 + order.id,
      'number': 'INV/2026/${order.id.toString().padLeft(4, '0')}',
      'state': 'posted',
      'payment_state': status == OrderStatus.completed ? 'paid' : 'not_paid',
      'total': order.total,
      'currency': order.currency,
    });
  }
}