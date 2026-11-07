import '../api/api_client.dart';
import '../models/whatsapp.dart';
import 'whatsapp_repository.dart';

class OdooWhatsAppRepository implements WhatsAppRepository {
  OdooWhatsAppRepository(this._api);

  final ApiClient _api;

  @override
  Future<WhatsAppPreview> preview({
    required int orderId,
    required String template,
    String? customMessage,
    String? phone,
  }) async {
    final query = <String, String>{
      'template': template,
      if (customMessage != null && customMessage.isNotEmpty)
        'custom_message': customMessage,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    };

    final json = await _api.get(
      '/api/laundry/orders/$orderId/whatsapp-preview',
      query: query,
    );
    final data = json['data'] as Map<String, dynamic>;
    return WhatsAppPreview.fromJson(data);
  }

  @override
  Future<void> send({
    required int orderId,
    required String template,
    String? customMessage,
    String? phone,
    bool sendImmediate = true,
  }) async {
    final body = <String, dynamic>{
      'template': template,
      'send_immediate': sendImmediate,
      if (customMessage != null && customMessage.isNotEmpty)
        'custom_message': customMessage,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    };

    await _api.post(
      '/api/laundry/orders/$orderId/send-whatsapp',
      body: body,
    );
  }

  @override
  Future<WhatsAppStatus> status(int orderId) async {
    final json = await _api.get('/api/laundry/orders/$orderId/whatsapp-status');
    final data = json['data'] as Map<String, dynamic>;
    return WhatsAppStatus.fromJson(data);
  }
}

