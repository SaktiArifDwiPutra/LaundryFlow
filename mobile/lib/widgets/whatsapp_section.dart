import 'package:flutter/material.dart';

import '../models/order.dart';
import '../models/whatsapp.dart';
import '../repositories/repositories.dart';
import '../theme/app_colors.dart';

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
                Icon(Icons.chat, color: AppColors.success),
                SizedBox(width: 8),
                Text('Kirim Notifikasi WhatsApp'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedTemplate,
                    decoration: const InputDecoration(
                      labelText: 'Pilih Template Pesan',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'invoice',
                        child: Text('Nota / Faktur Digital'),
                      ),
                      DropdownMenuItem(
                        value: 'ready',
                        child: Text('Cucian Siap Diambil / Diantar'),
                      ),
                      DropdownMenuItem(
                        value: 'reminder',
                        child: Text('Pengingat Cucian'),
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
                      prefixIcon: Icon(Icons.phone_outlined, size: 20),
                    ),
                  ),
                  if (selectedTemplate == 'custom') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: customMsgController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Isi Pesan Kustom',
                        hintText: 'Tulis pesan langsung untuk pelanggan...',
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.visibility, size: 18),
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
                            title: const Text('Pratinjau Pesan'),
                            content: SingleChildScrollView(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.successLight.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: SelectableText(
                                  preview.message,
                                  style: const TextStyle(fontSize: 13, height: 1.4),
                                ),
                              ),
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
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Gagal membuat pratinjau: $e')),
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
                style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                icon: const Icon(Icons.send, size: 18),
                label: const Text('Kirim WhatsApp'),
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
        const SnackBar(content: Text('Pesan WhatsApp berhasil dikirim ke server Odoo.')),
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
              'Notifikasi WhatsApp Pelanggan',
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
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: (hasSent ? AppColors.success : AppColors.neutral)
                                .withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.chat_bubble_outline,
                            size: 18,
                            color: hasSent ? AppColors.success : AppColors.neutral,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hasSent
                                    ? 'Notifikasi Terkirim'
                                    : 'Belum Ada Notifikasi Terkirim',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              Text(
                                hasSent
                                    ? 'Nomor: ${status?.phone ?? widget.order.customer.phone}'
                                    : 'Pelanggan: ${widget.order.customer.phone.isNotEmpty ? widget.order.customer.phone : 'Belum ada nomor HP'}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (hasSent ? AppColors.successLight : AppColors.neutralLight),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            hasSent ? 'TERKIRIM' : 'BELUM KIRIM',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: hasSent ? AppColors.successText : AppColors.neutral,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (status?.lastSent != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Waktu Terakhir: ${status!.lastSent}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const Divider(height: 24),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _sending
                              ? null
                              : () => _openSendDialog('invoice'),
                          icon: const Icon(Icons.receipt_long, size: 16),
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
