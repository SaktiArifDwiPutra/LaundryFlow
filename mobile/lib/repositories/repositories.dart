import 'customer_repository.dart';
import 'mock_customer_repository.dart';
import 'mock_order_repository.dart';
import 'order_repository.dart';

final OrderRepository orderRepository = MockOrderRepository();
final CustomerRepository customerRepository = MockCustomerRepository();