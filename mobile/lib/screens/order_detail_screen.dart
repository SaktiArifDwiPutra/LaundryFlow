import 'package:flutter/material.dart';

import '../models/order.dart';
import '../models/order_option.dart';
import '../models/order_status.dart';
import '../repositories/order_repository.dart';
import '../repositories/repositories.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import '../widgets/invoice_section.dart';
import '../widgets/order_badges.dart';
import '../widgets/status_chip.dart';
import '../widgets/whatsapp_section.dart';

class _FulfillmentChoice {
  const _FulfillmentChoice(this.fulfillment, this.address, this.fee);

  final Fulfillment fulfillment;
  final String address;
  final int fee;
}

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final int orderId;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Future<Order> _future;
  bool _saving = false;

  static const _editableStatuses = {
    OrderStatus.received,
    OrderStatus.washing,
    OrderStatus.drying,
    OrderStatus.ironing,
    OrderStatus.ready,
  };

  @override
  void initState() {
    super.initState();
    _future = orderRepository.get(widget.orderId);
  }

  void _reload() {
    setState(() {
      _future = orderRepository.get(widget.orderId);
    });
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _confirmText(Order order, OrderStatus next) {
    if (next == OrderStatus.ready) {
      return order.fulfillment == Fulfillment.delivery
          ? 'Pelanggan akan diberi tahu lewat WhatsApp bahwa cucian akan segera diantar.'
          : 'Pelanggan akan diberi tahu lewat WhatsApp bahwa cucian sudah selesai dan siap diambil.';
    }
    return 'Status pesanan ${order.number} akan diubah dari "${order.status.label}" ke "${next.label}".';
  }

  Future<void> _advance(Order order) async {
    final next = order.nextStatus;
    if (next == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ubah ke "${next.label}"?'),
        content: Text(_confirmText(order, next)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ya, Lanjutkan'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      final updated = await orderRepository.advanceStatus(order.id, next);
      if (!mounted) return;
      setState(() {
        _future = Future.value(updated);
      });
      _toast('Status pesanan berhasil diubah ke ${next.label}');
    } on InvalidTransitionException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editFulfillment(Order order) async {
    final choice = await showDialog<_FulfillmentChoice>(
      context: context,
      builder: (_) => _FulfillmentDialog(order: order),
    );
    if (choice == null || !mounted) return;

    setState(() => _saving = true);
    try {
      final updated = await orderRepository.setFulfillment(
        order.id,
        choice.fulfillment,
        deliveryAddress: choice.address,
        deliveryFee: choice.fee,
      );
      if (!mounted) return;
      setState(() {
        _future = Future.value(updated);
      });
    } on InvalidTransitionException catch (e) {
      _toast(e.message);
    } on OrderValidationException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return FutureBuilder<Order>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(title: const Text('Detail Pesanan')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Detail Pesanan')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
                    const SizedBox(height: 12),
                    Text('Gagal memuat pesanan: ${snapshot.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Muat Ulang'),
                      onPressed: _reload,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final order = snapshot.data!;
        final next = order.nextStatus;
        final due = order.dueAt;
        final servicesTotal =
            order.lines.fold<int>(0, (sum, l) => sum + l.subtotal);
        final delivery = order.delivery;
        final deliveryFee = delivery?.fee ?? 0;
        final canEditFulfillment = _editableStatuses.contains(order.status);
        final payColor = AppColors.paymentStatus(order.paymentStatus, isDark: isDark);

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      order.number,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: payColor.bg,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        order.paymentLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: payColor.text,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  order.customer.name.isEmpty ? 'Pelanggan Umum' : order.customer.name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Muat Ulang',
                icon: const Icon(Icons.refresh),
                onPressed: _reload,
              ),
              const SizedBox(width: 4),
            ],
          ),

          // Pinned Bottom Action Bar (Gaptek Cashier Friendly: Never miss the Next Stage button!)
          bottomNavigationBar: (next != null)
              ? Container(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomInset),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    border: Border(
                      top: BorderSide(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        width: 1,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? const Color(0x33000000) : const Color(0x0C000000),
                        blurRadius: 16,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Tahap Selanjutnya:',
                              style: TextStyle(fontSize: 11, color: AppColors.neutral),
                            ),
                            Text(
                              next.label,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: next == OrderStatus.ready ? AppColors.success : AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton(
                        onPressed: _saving ? null : () => _advance(order),
                        style: FilledButton.styleFrom(
                          backgroundColor: next == OrderStatus.ready ? AppColors.success : AppColors.primary,
                          minimumSize: const Size(160, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    next == OrderStatus.ready ? Icons.check_circle : Icons.arrow_forward,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    next == OrderStatus.ready ? 'Siap Diambil' : 'Lanjut Status',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                )
              : null,

          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              // 1. Hero Status Card
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    width: 1,
                  ),
                  boxShadow: AppColors.cardShadow(isDark: isDark),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              StatusChip(status: order.status),
                              if (order.priority == OrderPriority.express ||
                                  order.priority == OrderPriority.sameDay) ...[
                                const SizedBox(width: 6),
                                PriorityBadge(label: order.priority.label),
                              ],
                            ],
                          ),
                          DueLabel(order: order),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Waktu Pembuatan:',
                                  style: TextStyle(fontSize: 11, color: AppColors.neutral),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}  ${order.createdAt.hour.toString().padLeft(2, '0')}:${order.createdAt.minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          FulfillmentBadge(fulfillment: order.fulfillment),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              if (order.isOverdue && due != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.alarm, color: AppColors.danger, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Pesanan ini terlambat ${formatOverdue(due)} dari tenggat waktu.',
                          style: const TextStyle(
                            color: AppColors.dangerText,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),

              // 2. Workflow Stage Progress Bar
              const Text(
                'Alur Pengerjaan Cucian',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    width: 1,
                  ),
                  boxShadow: AppColors.cardShadow(isDark: isDark),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _StageProgress(order: order),
                ),
              ),
              const SizedBox(height: 18),

              // 3. Customer Info Card
              const Text(
                'Informasi Pelanggan',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    width: 1,
                  ),
                  boxShadow: AppColors.cardShadow(isDark: isDark),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            order.customer.name.isNotEmpty
                                ? order.customer.name[0].toUpperCase()
                                : 'P',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.customer.name.isEmpty
                                  ? 'Pelanggan Umum'
                                  : order.customer.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.phone_outlined, size: 14, color: AppColors.neutral),
                                const SizedBox(width: 4),
                                Text(
                                  order.customer.phone.isEmpty
                                      ? 'Tidak ada nomor telepon'
                                      : order.customer.phone,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.neutral,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // 4. Delivery/Pickup Card
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    width: 1,
                  ),
                  boxShadow: AppColors.cardShadow(isDark: isDark),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            order.fulfillment == Fulfillment.delivery
                                ? Icons.delivery_dining_outlined
                                : Icons.storefront_outlined,
                            size: 20,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              order.fulfillment == Fulfillment.delivery
                                  ? 'Pengantaran ke Alamat'
                                  : 'Ambil Sendiri di Toko',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (canEditFulfillment)
                            TextButton(
                              onPressed: _saving ? null : () => _editFulfillment(order),
                              child: const Text('Ubah'),
                            ),
                        ],
                      ),
                      if (delivery != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Alamat: ${delivery.address.isEmpty ? '-' : delivery.address}',
                          style: textTheme.bodySmall,
                        ),
                        if (deliveryFee > 0)
                          Text('Ongkos Kirim: ${formatRupiah(deliveryFee)}', style: textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // 5. Itemized Receipt Card
              const Text(
                'Rincian Layanan & Biaya',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    width: 1,
                  ),
                  boxShadow: AppColors.cardShadow(isDark: isDark),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final line in order.lines) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      line.serviceName,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      '${formatQty(line.qty)} ${line.unit} × ${formatRupiah(line.unitPrice)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                      ),
                                    ),
                                    if (line.itemDetails.isNotEmpty)
                                      Text(
                                        'Detail: ${line.itemDetails}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontStyle: FontStyle.italic,
                                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Text(
                                formatRupiah(line.subtotal),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 12),
                      ],
                      const SizedBox(height: 4),
                      _MoneyRow(label: 'Total Layanan', value: formatRupiah(servicesTotal)),
                      if (order.expressFee > 0)
                        _MoneyRow(
                          label: 'Biaya Same Day',
                          value: formatRupiah(order.expressFee),
                        ),
                      if (deliveryFee > 0)
                        _MoneyRow(label: 'Ongkos Kirim', value: formatRupiah(deliveryFee)),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Keseluruhan',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                          Text(
                            formatRupiah(order.total),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              if (order.notes.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('Catatan Pesanan: ${order.notes}', style: textTheme.bodyMedium),
                ),
              ],
              const SizedBox(height: 20),

              // 6. Invoice & Payment Section
              InvoiceSection(
                key: ValueKey('${order.id}-${order.status.code}'),
                orderId: order.id,
                onPaymentSuccess: _reload,
              ),
              const SizedBox(height: 20),

              // 7. WhatsApp Notification Section
              WhatsAppSection(
                key: ValueKey('wa-${order.id}-${order.status.code}'),
                order: order,
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(value, style: style)],
      ),
    );
  }
}

class _StageProgress extends StatelessWidget {
  const _StageProgress({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final stages = order.stages;
    final current = stages.indexOf(order.status);
    if (stages.isEmpty || current < 0) return const SizedBox.shrink();
    final primary = AppColors.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Wrap(
      spacing: 6,
      runSpacing: 8,
      children: [
        for (var i = 0; i < stages.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: i == current
                  ? primary.withValues(alpha: isDark ? 0.25 : 0.12)
                  : (i < current
                      ? AppColors.successLight
                      : (isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated)),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: i == current
                    ? primary
                    : (i < current
                        ? AppColors.success.withValues(alpha: 0.5)
                        : (isDark ? AppColors.darkBorder : AppColors.lightBorder)),
                width: i == current ? 1.8 : 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (i < current) ...[
                  const Icon(Icons.check, size: 12, color: AppColors.success),
                  const SizedBox(width: 4),
                ] else if (i == current) ...[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  stages[i].label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: i == current ? FontWeight.w700 : FontWeight.w500,
                    color: i == current
                        ? primary
                        : (i < current ? AppColors.successText : AppColors.neutral),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _FulfillmentDialog extends StatefulWidget {
  const _FulfillmentDialog({required this.order});

  final Order order;

  @override
  State<_FulfillmentDialog> createState() => _FulfillmentDialogState();
}

class _FulfillmentDialogState extends State<_FulfillmentDialog> {
  late Fulfillment _fulfillment = widget.order.fulfillment;
  late final TextEditingController _address =
      TextEditingController(text: widget.order.delivery?.address ?? '');
  late final TextEditingController _fee =
      TextEditingController(text: formatRupiah(widget.order.delivery?.fee ?? 0));

  @override
  void dispose() {
    _address.dispose();
    _fee.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ubah Pengambilan / Pengantaran'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<Fulfillment>(
              segments: const [
                ButtonSegment(
                  value: Fulfillment.pickup,
                  label: Text('Ambil Sendiri'),
                  icon: Icon(Icons.storefront_outlined),
                ),
                ButtonSegment(
                  value: Fulfillment.delivery,
                  label: Text('Diantar'),
                  icon: Icon(Icons.delivery_dining_outlined),
                ),
              ],
              selected: {_fulfillment},
              onSelectionChanged: (set) {
                setState(() => _fulfillment = set.first);
              },
            ),
            if (_fulfillment == Fulfillment.delivery) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _address,
                decoration: const InputDecoration(
                  labelText: 'Alamat Pengantaran',
                  hintText: 'Jl. Contoh No. 123',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _fee,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Ongkos Kirim (Rp)',
                  hintText: 'Contoh: 10000',
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () {
            final fee = _fulfillment == Fulfillment.delivery
                ? parseRupiah(_fee.text)
                : 0;
            Navigator.of(context).pop(
              _FulfillmentChoice(
                _fulfillment,
                _fulfillment == Fulfillment.delivery ? _address.text.trim() : '',
                fee,
              ),
            );
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
