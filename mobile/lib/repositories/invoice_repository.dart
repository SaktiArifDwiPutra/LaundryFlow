import '../models/invoice.dart';

abstract class InvoiceRepository {
  Future<Invoice?> getForOrder(int orderId);
}