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
    final phoneController =
        TextEditingController(text: widget.order.customer.phone);

    final bool? sendConfirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.chat_rounded, color: AppColors.teal),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Kirim Notifikasi WhatsApp',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedTemplate,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Pilih Template Pesan',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'invoice',
                        child: Text(
                          'Nota / Faktur Digital',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'ready',
                        child: Text(
                          'Cucian Siap Diambil / Diantar',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'reminder',
                        child: Text(
                          'Pengingat Cucian',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'custom',
                        child: Text(
                          'Pesan Kustom',
                          overflow: TextOverflow.ellipsis,
                        ),
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
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text(
                      'Pratinjau Pesan (Preview)',
                      overflow: TextOverflow.ellipsis,
                    ),
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
                                  color:
                                      AppColors.tealLight.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: SelectableText(
                                  preview.message,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
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
                          SnackBar(
                            content: Text('Gagal membuat pratinjau: $e'),
                          ),
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
                style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
                icon: const Icon(Icons.send_rounded, size: 18),
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
        const SnackBar(
          content: Text('Pesan WhatsApp berhasil dikirim ke server Odoo.'),
        ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: AppColors.teal.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.chat_rounded,
                    size: 15,
                    color: AppColors.teal,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Notifikasi WhatsApp Pelanggan',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
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

            return Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: hasSent
                      ? AppColors.teal.withValues(alpha: 0.45)
                      : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  width: 1.3,
                ),
                boxShadow: AppColors.cardShadow(isDark: isDark),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: (hasSent ? AppColors.teal : AppColors.neutral)
                                .withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Icon(
                            Icons.mark_chat_read_rounded,
                            size: 19,
                            color: hasSent ? AppColors.teal : AppColors.neutral,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hasSent
                                    ? 'Notifikasi WhatsApp Terkirim'
                                    : 'Siap Kirim Notifikasi WhatsApp',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                ),
                              ),
                              Text(
                                hasSent
                                    ? 'Nomor: ${status?.phone ?? widget.order.customer.phone}'
                                    : 'Tujuan: ${widget.order.customer.phone.isNotEmpty ? widget.order.customer.phone : 'Belum ada nomor HP'}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: hasSent
                                ? (isDark
                                    ? AppColors.tealDark.withValues(alpha: 0.5)
                                    : AppColors.tealLight)
                                : (isDark
                                    ? AppColors.darkSurfaceElevated
                                    : AppColors.neutralLight),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            hasSent ? 'TERKIRIM' : 'BELUM KIRIM',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: hasSent
                                  ? (isDark ? AppColors.tealGlow : AppColors.teal)
                                  : AppColors.neutral,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (status?.lastSent != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Terakhir dikirim: ${status!.lastSent}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const Divider(height: 22),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _WaActionChip(
                          icon: Icons.receipt_long_rounded,
                          label: 'Kirim Nota',
                          color: AppColors.primaryBright,
                          isDark: isDark,
                          onTap: _sending
                              ? null
                              : () => _openSendDialog('invoice'),
                        ),
                        _WaActionChip(
                          icon: Icons.check_circle_rounded,
                          label: 'Kirim Siap Ambil',
                          color: AppColors.teal,
                          isDark: isDark,
                          onTap:
                              _sending ? null : () => _openSendDialog('ready'),
                        ),
                        _WaActionChip(
                          icon: Icons.edit_note_rounded,
                          label: 'Pesan Kustom',
                          color: AppColors.violet,
                          isDark: isDark,
                          onTap:
                              _sending ? null : () => _openSendDialog('custom'),
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

class _WaActionChip extends StatelessWidget {
  const _WaActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.18 : 0.09),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
