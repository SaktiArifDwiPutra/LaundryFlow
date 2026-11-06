import 'package:flutter/material.dart';

import '../models/order.dart';
import '../models/whatsapp.dart';
import '../repositories/repositories.dart';

class WhatsAppSection extends StatefulWidget {
  const WhatsAppSection({super.key, required this.order});

  final Order order;

  @override
  State<WhatsAppSection> createState() => _WhatsAppSectionState();
}

class _WhatsAppSectionState extends State<WhatsAppSection> {
  late Future<WhatsAppStatus> _future;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = whatsappRepository.status(widget.order.id);
    });
  }

  Future<void> _openSendDialog(String defaultTemplate) async {
    String selectedTemplate = defaultTemplate;
    final customMsgController = TextEditingController();
    final phoneController = TextEditingController(text: widget.order.customer.phone);

    final bool? sendConfirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.chat, color: Colors.green),
                SizedBox(width: 8),
                Text('Kirim WhatsApp'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedTemplate,
                    decoration: const InputDecoration(
                      labelText: 'Pilih Template',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'invoice',
                        child: Text('Nota / Invoice'),
                      ),
                      DropdownMenuItem(
                        value: 'ready',
                        child: Text('Pesanan Siap Diambil'),
                      ),
                      DropdownMenuItem(
                        value: 'reminder',
                        child: Text('Pengingat Pesanan'),
                      ),
                      DropdownMenuItem(
                        value: 'custom',
                        child: Text('Pesan Kustom'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedTemplate = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Nomor WhatsApp Penerima',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (selectedTemplate == 'custom') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: customMsgController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Isi Pesan Kustom',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.visibility),
                    label: const Text('Pratinjau Pesan (Preview)'),
                    onPressed: () async {
                      try {
                        final preview = await whatsappRepository.preview(
                          orderId: widget.order.id,
                          template: selectedTemplate,
                          customMessage: selectedTemplate == 'custom'
                              ? customMsgController.text.trim()
                              : null,
                          phone: phoneController.text.trim().isNotEmpty
                              ? phoneController.text.trim()
                              : null,
                        );
                        if (!ctx.mounted) return;
                        showDialog(
                          context: ctx,
                          builder: (_) => AlertDialog(
                            title: const Text('Pratinjau WhatsApp'),
                            content: SingleChildScrollView(
                              child: SelectableText(preview.message),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                child: const Text('Tutup'),
                              ),
                            ],
                          ),
                        );
                      } catch (e) {
                        if (!ctx.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Gagal pratinjau: $e')),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Batal'),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.send),
                label: const Text('Kirim Sekarang'),
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
            ],
          );
        },
      ),
    );

    if (sendConfirmed != true || !mounted) return;

    setState(() => _sending = true);
    try {
      await whatsappRepository.send(
        orderId: widget.order.id,
        template: selectedTemplate,
        customMessage: selectedTemplate == 'custom'
            ? customMsgController.text.trim()
            : null,
        phone: phoneController.text.trim().isNotEmpty
            ? phoneController.text.trim()
            : null,
        sendImmediate: true,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notifikasi WhatsApp berhasil diproses.')),
      );
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengirim WhatsApp: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Notifikasi WhatsApp',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (_sending)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 8),
        FutureBuilder<WhatsAppStatus>(
          future: _future,
          builder: (context, snapshot) {
            final status = snapshot.data;
            final isDelivered = status?.status == 'delivered';
            final hasSent = status?.isSent == true || isDelivered;

            return Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 20,
                          color: hasSent ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            hasSent
                                ? 'Terkirim ke ${status?.phone ?? widget.order.customer.phone}'
                                : 'Belum ada notifikasi WhatsApp terkirim',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: (hasSent ? Colors.green : Colors.grey)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            status?.status.toUpperCase() ?? 'NONE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: hasSent ? Colors.green : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (status?.lastSent != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Waktu: ${status!.lastSent}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const Divider(height: 20),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _sending
                              ? null
                              : () => _openSendDialog('invoice'),
                          icon: const Icon(Icons.receipt, size: 16),
                          label: const Text('Kirim Nota'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _sending
                              ? null
                              : () => _openSendDialog('ready'),
                          icon: const Icon(Icons.check_circle_outline, size: 16),
                          label: const Text('Kirim Siap Ambil'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _sending
                              ? null
                              : () => _openSendDialog('custom'),
                          icon: const Icon(Icons.edit_note, size: 16),
                          label: const Text('Pesan Kustom'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
