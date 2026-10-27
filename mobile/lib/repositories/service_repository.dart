import '../models/service.dart';

abstract class ServiceRepository {
  Future<List<Service>> list();
}