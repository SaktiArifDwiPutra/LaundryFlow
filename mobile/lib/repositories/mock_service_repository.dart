import '../data/mock_services.dart';
import '../models/service.dart';
import 'service_repository.dart';

class MockServiceRepository implements ServiceRepository {
  @override
  Future<List<Service>> list() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return List.unmodifiable(mockServices);
  }
}