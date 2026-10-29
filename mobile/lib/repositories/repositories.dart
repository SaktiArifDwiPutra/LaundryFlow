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
import 'odoo_service_repository.dart';

final ApiClient apiClient = ApiClient(
  baseUrl: baseUrl,
  onUnauthorized: () => currentUser.value = null,
);

final AuthRepository authRepository =
    useMock ? MockAuthRepository() : OdooAuthRepository(apiClient);
final CustomerRepository customerRepository =
    useMock ? MockCustomerRepository() : OdooCustomerRepository(apiClient);
 
final OrderRepository orderRepository = MockOrderRepository();
final ServiceRepository serviceRepository =
    useMock ? MockServiceRepository() : OdooServiceRepository(apiClient);
final InvoiceRepository invoiceRepository =
    MockInvoiceRepository(orderRepository);