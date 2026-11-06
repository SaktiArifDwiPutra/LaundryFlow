import '../data/mock_services.dart';
import '../models/service.dart';
import '../models/service_speed.dart';
import 'service_repository.dart';

class MockServiceRepository implements ServiceRepository {
  Future<void> _fakeDelay() =>
      Future.delayed(const Duration(milliseconds: 400));

  @override
  Future<List<Service>> list() async {
    await _fakeDelay();
    return List.unmodifiable(mockServices);
  }

  @override
  Future<List<ServiceSpeed>> speeds() async {
    await _fakeDelay();
    return List.unmodifiable(mockServiceSpeeds);
  }
}