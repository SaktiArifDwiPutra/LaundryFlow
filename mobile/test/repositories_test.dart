import 'package:flutter_test/flutter_test.dart';
import 'package:laundryflow/models/customer.dart';
import 'package:laundryflow/models/order_status.dart';
import 'package:laundryflow/models/service.dart';
import 'package:laundryflow/repositories/mock_auth_repository.dart';
import 'package:laundryflow/repositories/mock_customer_repository.dart';
import 'package:laundryflow/repositories/mock_invoice_repository.dart';
import 'package:laundryflow/repositories/mock_order_repository.dart';
import 'package:laundryflow/repositories/mock_service_repository.dart';
import 'package:laundryflow/repositories/mock_whatsapp_repository.dart';
import 'package:laundryflow/repositories/order_repository.dart';

void main() {
  group('Mock Auth Repository Tests', () {
    final auth = MockAuthRepository();

    test('login with valid credentials succeeds', () async {
      final user = await auth.login(login: 'staf', password: 'staf123');
      expect(user.name, 'Staf Satu');
      expect(user.sessionId.isNotEmpty, isTrue);
    });

    test('login with invalid credentials throws', () async {
      expect(
        () => auth.login(login: 'wrong', password: 'wrong'),
        throwsException,
      );
    });
  });

  group('Mock Customer Repository Tests', () {
    final repo = MockCustomerRepository();

    test('lists customers with search query', () async {
      final list = await repo.list(q: 'budi');
      expect(list.isNotEmpty, isTrue);
    });

    test('creates and deletes customer', () async {
      final created = await repo.create(
        name: 'Test Customer',
        phone: '081200001111',
        address: 'Jl. Uji Coba 1',
      );
      expect(created.name, 'Test Customer');

      final search = await repo.list(q: 'Test Customer');
      expect(search.any((c) => c.name == 'Test Customer'), isTrue);

      await repo.delete(created.id);
      final searchAfter = await repo.list(q: 'Test Customer');
      expect(searchAfter.isEmpty, isTrue);
    });
  });

  group('Mock Services Repository Tests', () {
    final repo = MockServiceRepository();

    test('fetches services and speeds', () async {
      final services = await repo.list();
      expect(services.isNotEmpty, isTrue);

      final speeds = await repo.speeds();
      expect(speeds.isNotEmpty, isTrue);
      expect(speeds.any((s) => s.isSameDay), isTrue);
    });
  });

  group('Mock Orders and Invoices Integration Tests', () {
    final orderRepo = MockOrderRepository();
    final invoiceRepo = MockInvoiceRepository(orderRepo);

    test('creates order and records cashier payment', () async {
      final customer = Customer(id: 1, name: 'Budi Santoso', phone: '0812345678');
      final service = Service(
        id: 1,
        name: 'Cuci Setrika',
        pricingType: PricingType.weight,
        unit: 'kg',
        unitPrice: 10000,
      );

      final order = await orderRepo.create(
        customer: customer,
        lines: [
          OrderLineInput(
            service: service,
            weight: 3.5,
          ),
        ],
      );

      expect(order.id, greaterThan(0));
      expect(order.total, 35000);

      // Verify invoice retrieval
      final invoice = await invoiceRepo.getForOrder(order.id);
      expect(invoice, isNotNull);
      expect(invoice!.total, 35000);
      expect(invoice.isPaid, isFalse);

      // Record full cashier payment
      final paidInvoice = await invoiceRepo.recordPayment(
        orderId: order.id,
        paymentMethod: 'cash',
        amountPaid: 50000,
        notes: 'Uang 50rb',
      );

      expect(paidInvoice.isPaid, isTrue);
      expect(paidInvoice.amountPaid, 50000);
      expect(paidInvoice.amountDue, 0);
      expect(paidInvoice.changeAmount, 15000);
      expect(paidInvoice.paymentMethod, 'cash');

      // Test status transition
      final advanced = await orderRepo.advanceStatus(order.id, OrderStatus.washing);
      expect(advanced.status, OrderStatus.washing);
    });
  });

  group('Mock WhatsApp Repository Tests', () {
    final repo = MockWhatsAppRepository();

    test('preview and send notification', () async {
      final preview = await repo.preview(orderId: 1, template: 'ready');
      expect(preview.message.contains('siap diambil'), isTrue);

      await repo.send(orderId: 1, template: 'ready');

      final status = await repo.status(1);
      expect(status.isSent, isTrue);
    });
  });
}
