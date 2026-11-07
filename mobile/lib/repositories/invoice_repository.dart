import '../models/invoice.dart';

abstract class InvoiceRepository {
  Future<Invoice?> getForOrder(int orderId);

  Future<Invoice> recordPayment({
    required int orderId,
    required String paymentMethod,
    int? amountPaid,
    String? reference,
    String? notes,
  });
}