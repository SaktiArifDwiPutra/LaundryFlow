class WhatsAppHistoryItem {
  const WhatsAppHistoryItem({
    required this.id,
    required this.name,
    required this.phone,
    required this.isDelivered,
    required this.isQueued,
    this.sentDate,
    this.createDate,
    this.errorMsg,
    this.messagePreview,
  });

  final int id;
  final String name;
  final String phone;
  final bool isDelivered;
  final bool isQueued;
  final String? sentDate;
  final String? createDate;
  final String? errorMsg;
  final String? messagePreview;

  factory WhatsAppHistoryItem.fromJson(Map<String, dynamic> json) {
    return WhatsAppHistoryItem(
      id: (json['id'] as int?) ?? 0,
      name: (json['name'] as String?) ?? '',
      phone: (json['phone'] as String?) ?? '',
      isDelivered: json['is_delivered'] as bool? ?? false,
      isQueued: json['is_queued'] as bool? ?? false,
      sentDate: json['sent_date'] as String?,
      createDate: json['create_date'] as String?,
      errorMsg: json['error_msg'] as String?,
      messagePreview: json['message_preview'] as String?,
    );
  }
}

class WhatsAppStatus {
  const WhatsAppStatus({
    required this.orderId,
    required this.orderNumber,
    required this.status,
    required this.phone,
    required this.isSent,
    this.lastSent,
    this.outboxCount = 0,
    this.history = const [],
  });

  final int orderId;
  final String orderNumber;
  final String status;
  final String phone;
  final bool isSent;
  final String? lastSent;
  final int outboxCount;
  final List<WhatsAppHistoryItem> history;

  factory WhatsAppStatus.fromJson(Map<String, dynamic> json) {
    final historyList = (json['history'] as List<dynamic>? ?? const [])
        .map((e) => WhatsAppHistoryItem.fromJson(e as Map<String, dynamic>))
        .toList();

    return WhatsAppStatus(
      orderId: (json['order_id'] as int?) ?? 0,
      orderNumber: (json['order_number'] as String?) ?? '',
      status: (json['whatsapp_status'] as String?) ?? 'none',
      phone: (json['whatsapp_phone'] as String?) ?? '',
      isSent: json['whatsapp_sent'] as bool? ?? false,
      lastSent: json['whatsapp_last_sent'] as String?,
      outboxCount: (json['outbox_count'] as int?) ?? 0,
      history: historyList,
    );
  }
}

class WhatsAppPreview {
  const WhatsAppPreview({
    required this.orderId,
    required this.orderNumber,
    required this.customerName,
    required this.template,
    required this.recipientPhone,
    required this.message,
    this.characterCount = 0,
  });

  final int orderId;
  final String orderNumber;
  final String customerName;
  final String template;
  final String recipientPhone;
  final String message;
  final int characterCount;

  factory WhatsAppPreview.fromJson(Map<String, dynamic> json) {
    return WhatsAppPreview(
      orderId: (json['order_id'] as int?) ?? 0,
      orderNumber: (json['order_number'] as String?) ?? '',
      customerName: (json['customer_name'] as String?) ?? '',
      template: (json['template'] as String?) ?? '',
      recipientPhone: (json['recipient_phone'] as String?) ?? '',
      message: (json['message'] as String?) ?? '',
      characterCount: (json['character_count'] as int?) ?? 0,
    );
  }
}

