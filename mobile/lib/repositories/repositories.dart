import '../api/api_client.dart';
import '../config.dart';
import '../session.dart';
import 'auth_repository.dart';
import 'customer_repository.dart';
import 'invoice_repository.dart';
import 'mock_auth_repository.dart';
import 'mock_customer_repository.dart';
import 'mock_invoice_repository.dart';
import 'mock_order_repository.dart';
import 'mock_service_repository.dart';
import 'odoo_auth_repository.dart';
import 'odoo_customer_repository.dart';
import 'order_repository.dart';
import 'service_repository.dart';

final ApiClient apiClient = ApiClient(
  baseUrl: baseUrl,
  onUnauthorized: () => currentUser.value = null,
);

/// Satu-satunya tempat memilih sumber data.
/// USE_MOCK=false memakai backend untuk login dan cari pelanggan.
final AuthRepository authRepository =
    useMock ? MockAuthRepository() : OdooAuthRepository(apiClient);
final CustomerRepository customerRepository =
    useMock ? MockCustomerRepository() : OdooCustomerRepository(apiClient);

// Endpoint pesanan, layanan, dan invoice belum ada di backend, jadi tetap mock.
final OrderRepository orderRepository = MockOrderRepository();
final ServiceRepository serviceRepository = MockServiceRepository();
final InvoiceRepository invoiceRepository =
    MockInvoiceRepository(orderRepository);