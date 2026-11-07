import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../models/invoice.dart';
import 'invoice_repository.dart';

class OdooInvoiceRepository implements InvoiceRepository {
  OdooInvoiceRepository(this._api);

  final ApiClient _api;

  @override
  Future<Invoice?> getForOrder(int orderId) async {
    try {
      final json = await _api.get('/api/orders/$orderId/invoice');
      final data = json['data'];
      if (data is Map<String, dynamic>) {
        return Invoice.fromJson(data);
      }
      return null;
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<Invoice> recordPayment({
    required int orderId,
    required String paymentMethod,
    int? amountPaid,
    String? reference,
    String? notes,
  }) async {
    final body = <String, dynamic>{
      'payment_method': paymentMethod,
      'amount_paid': ?amountPaid,
      if (reference != null && reference.isNotEmpty) 'reference': reference,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };

    final json = await _api.post('/api/orders/$orderId/payment', body: body);
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      return Invoice.fromJson(data);
    }
    final refreshed = await getForOrder(orderId);
    if (refreshed != null) return refreshed;
    throw const ApiException('Gagal memproses respons pembayaran.');
  }
}
