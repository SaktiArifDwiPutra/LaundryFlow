import '../models/invoice.dart';
import 'invoice_repository.dart';
import 'order_repository.dart';

class MockInvoiceRepository implements InvoiceRepository {
  MockInvoiceRepository(this._orders);

  final OrderRepository _orders;
  final Map<int, Invoice> _cache = {};

  @override
  Future<Invoice?> getForOrder(int orderId) async {
    if (_cache.containsKey(orderId)) {
      return _cache[orderId];
    }
    final order = await _orders.get(orderId);
    final inv = Invoice.fromJson({
      'order_id': order.id,
      'invoice_number': 'INV/LDR/2026/${order.id.toString().padLeft(4, '0')}',
      'order_number': order.number,
      'state': 'posted',
      'payment_status': order.isPaid ? 'paid' : 'unpaid',
      'total_amount': order.total,
      'amount_paid': order.isPaid ? order.total : 0,
      'amount_due': order.isPaid ? 0 : order.total,
      'change_amount': 0,
      'payment_method': order.isPaid ? 'cash' : '',
      'currency': order.currency,
    });
    _cache[orderId] = inv;
    return inv;
  }

  @override
  Future<Invoice> recordPayment({
    required int orderId,
    required String paymentMethod,
    int? amountPaid,
    String? reference,
    String? notes,
  }) async {
    final order = await _orders.get(orderId);
    final paid = amountPaid ?? order.total;
    final due = (order.total - paid).clamp(0, order.total);
    final change = (paid - order.total).clamp(0, 999999999);
    final status = due == 0 ? 'paid' : (paid > 0 ? 'partial' : 'unpaid');

    final updated = Invoice(
      id: order.id,
      number: 'INV/LDR/2026/${order.id.toString().padLeft(4, '0')}',
      orderId: order.id,
      orderNumber: order.number,
      state: 'posted',
      paymentState: status,
      total: order.total,
      amountPaid: paid,
      amountDue: due,
      changeAmount: change,
      paymentMethod: paymentMethod,
      paymentReference: reference,
      paymentDate: DateTime.now().toLocal().toString().substring(0, 19),
    );
    _cache[orderId] = updated;
    return updated;
  }
}
