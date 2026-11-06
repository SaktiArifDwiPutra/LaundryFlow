import '../models/service.dart';
import '../models/service_speed.dart';

abstract class ServiceRepository {
  /// Katalog layanan laundry (jasa saja, bukan bahan).
  Future<List<Service>> list();

  /// Pilihan kecepatan pengerjaan (Reguler / Same Day).
  Future<List<ServiceSpeed>> speeds();
}