import '../models/invoice.dart';
import 'invoice_repository.dart';

/// Implementasi repository invoice untuk mode backend Odoo.
/// Karena spesifikasi OpenAPI backend belum menyediakan endpoint invoice/pembayaran,
/// repository ini secara sah mengembalikan null agar UI menampilkan empty state / status
/// belum tersedia, bukan mengarang data palsu.
class OdooInvoiceRepository implements InvoiceRepository {
  @override
  Future<Invoice?> getForOrder(int orderId) async {
    return null;
  }
}
