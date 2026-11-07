import '../models/whatsapp.dart';

abstract class WhatsAppRepository {
  Future<WhatsAppPreview> preview({
    required int orderId,
    required String template,
    String? customMessage,
    String? phone,
  });

  Future<void> send({
    required int orderId,
    required String template,
    String? customMessage,
    String? phone,
    bool sendImmediate = true,
  });

  Future<WhatsAppStatus> status(int orderId);
}

