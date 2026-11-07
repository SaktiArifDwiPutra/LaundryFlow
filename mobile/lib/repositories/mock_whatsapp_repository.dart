import '../models/whatsapp.dart';
import 'whatsapp_repository.dart';

class MockWhatsAppRepository implements WhatsAppRepository {
  final Map<int, WhatsAppStatus> _statuses = {};

  @override
  Future<WhatsAppPreview> preview({
    required int orderId,
    required String template,
    String? customMessage,
    String? phone,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final msg = switch (template) {
      'invoice' =>
        '*NOTA TRANSAKSI LAUNDRYFLOW*\nHalo pelanggan, terima kasih telah mempercayakan cucian Anda di LaundryFlow.',
      'ready' =>
        '*PESANAN SIAP AMBIL*\nPesanan cucian Anda sudah selesai diproses dan siap diambil.',
      'reminder' =>
        '*PENGINGAT CUCIAN*\nPesanan cucian Anda sudah siap diambil sejak beberapa hari yang lalu.',
      _ => customMessage ?? 'Notifikasi LaundryFlow',
    };

    return WhatsAppPreview(
      orderId: orderId,
      orderNumber: 'LF-2026-$orderId',
      customerName: 'Pelanggan',
      template: template,
      recipientPhone: phone ?? '081234567890',
      message: msg,
      characterCount: msg.length,
    );
  }

  @override
  Future<void> send({
    required int orderId,
    required String template,
    String? customMessage,
    String? phone,
    bool sendImmediate = true,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _statuses[orderId] = WhatsAppStatus(
      orderId: orderId,
      orderNumber: 'LF-2026-$orderId',
      status: 'delivered',
      phone: phone ?? '081234567890',
      isSent: true,
      lastSent: DateTime.now().toLocal().toString().substring(0, 19),
      outboxCount: 1,
      history: [
        WhatsAppHistoryItem(
          id: 1,
          name: '$template - LF-2026-$orderId',
          phone: phone ?? '081234567890',
          isDelivered: true,
          isQueued: false,
          sentDate: DateTime.now().toLocal().toString().substring(0, 19),
          messagePreview: customMessage ?? 'Template $template terkirim',
        ),
      ],
    );
  }

  @override
  Future<WhatsAppStatus> status(int orderId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _statuses[orderId] ??
        WhatsAppStatus(
          orderId: orderId,
          orderNumber: 'LF-2026-$orderId',
          status: 'none',
          phone: '',
          isSent: false,
          outboxCount: 0,
        );
  }
}

