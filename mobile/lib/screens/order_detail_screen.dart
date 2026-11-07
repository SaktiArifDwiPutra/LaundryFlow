import 'package:flutter/material.dart';

import '../models/order.dart';
import '../models/order_option.dart';
import '../models/order_status.dart';
import '../repositories/order_repository.dart';
import '../repositories/repositories.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import '../widgets/fulfillment_fields.dart';
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
          ? 'Pelanggan akan diberi tahu lewat WhatsApp bahwa cucian akan segera diantar. Pesan yang sudah terkirim tidak bisa ditarik.'
          : 'Pelanggan akan diberi tahu lewat WhatsApp bahwa cucian siap diambil. Pesan yang sudah terkirim tidak bisa ditarik.';
    }
    return 'Status pesanan ${order.number} akan diubah dari "${order.status.label}" ke "${next.label}".';
  }

  Future<void> _advance(Order order) async {
    final next = order.nextStatus;
    if (next == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ubah status ke "${next.label}"?'),
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

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Pesanan')),
      body: SafeArea(
        child: FutureBuilder<Order>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
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

            return ListView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 32 + bottomInset),
              children: [
                // Card 1: Order Header
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    order.number,
                                    style: textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? AppColors.primaryLight : AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Dibuat: ${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year} ${order.createdAt.hour.toString().padLeft(2, '0')}:${order.createdAt.minute.toString().padLeft(2, '0')}',
                                    style: textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            _OrderPaymentBadge(order: order),
                            const SizedBox(width: 8),
                            StatusChip(status: order.status),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            if (order.priority == OrderPriority.express || order.priority == OrderPriority.sameDay) ...[
                              PriorityBadge(label: order.priority.label),
                              const SizedBox(width: 8),
                            ],
                            FulfillmentBadge(fulfillment: order.fulfillment),
                            const Spacer(),
                            DueLabel(order: order),
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
                      borderRadius: BorderRadius.circular(10),
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
                const SizedBox(height: 20),

                // Card 2: Workflow Stepper
                Text('Proses Pengerjaan', style: textTheme.titleMedium),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _StageProgress(order: order),
                  ),
                ),
                const SizedBox(height: 20),

                // Card 3: Customer Details
                Text('Pelanggan', style: textTheme.titleMedium),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person, color: AppColors.primary),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(order.customer.name, style: textTheme.titleMedium),
                              const SizedBox(height: 2),
                              Text(
                                order.customer.phone.isEmpty ? 'Tidak ada nomor telepon' : order.customer.phone,
                                style: textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Card 4: Fulfillment / Delivery
                Text('Pengambilan & Pengantaran', style: textTheme.titleMedium),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                order.fulfillment == Fulfillment.delivery
                                    ? 'Diantar ke Alamat Pelanggan'
                                    : 'Diambil Sendiri di Toko',
                                style: const TextStyle(fontWeight: FontWeight.w600),
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
                          const SizedBox(height: 6),
                          Text('Alamat: ${delivery.address.isEmpty ? '-' : delivery.address}'),
                          if (deliveryFee > 0)
                            Text('Ongkir: ${formatRupiah(deliveryFee)}'),
                          if (delivery.courierName != null)
                            Text('Kurir: ${delivery.courierName}'),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Card 5: Itemized Services
                Text('Layanan Terdaftar', style: textTheme.titleMedium),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      children: [
                        for (int i = 0; i < order.lines.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        order.lines[i].serviceName,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${formatQty(order.lines[i].qty)} ${order.lines[i].unit} × ${formatRupiah(order.lines[i].unitPrice)}',
                                        style: textTheme.bodySmall,
                                      ),
                                      if (order.lines[i].itemDetails.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          'Catatan: ${order.lines[i].itemDetails}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontStyle: FontStyle.italic,
                                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Text(
                                  formatRupiah(order.lines[i].subtotal),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Card 6: Financial Breakdown
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Rincian Pembayaran', style: textTheme.titleMedium),
                        const Divider(height: 20),
                        _MoneyRow(label: 'Total Layanan', value: formatRupiah(servicesTotal)),
                        if (order.expressFee > 0)
                          _MoneyRow(
                            label: 'Biaya Same Day',
                            value: formatRupiah(order.expressFee),
                          ),
                        if (deliveryFee > 0)
                          _MoneyRow(label: 'Ongkos Kirim', value: formatRupiah(deliveryFee)),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Tagihan',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              formatRupiah(order.total),
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: isDark ? AppColors.primaryLight : AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (order.notes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('Catatan Pesanan: ${order.notes}', style: textTheme.bodyMedium),
                  ),
                ],
                const SizedBox(height: 24),

                // Invoice & Cashier Section
                InvoiceSection(
                  key: ValueKey('${order.id}-${order.status.code}'),
                  orderId: order.id,
                  onPaymentSuccess: () {
                    setState(() {
                      _future = orderRepository.get(widget.orderId);
                    });
                  },
                ),
                const SizedBox(height: 24),

                // WhatsApp Section
                WhatsAppSection(
                  key: ValueKey('wa-${order.id}-${order.status.code}'),
                  order: order,
                ),
                const SizedBox(height: 24),

                // Action Button: Advance Status
                if (next != null)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: _saving ? null : () => _advance(order),
                      label: Text(
                        _saving ? 'Memperbarui...' : 'Lanjut Status: ${next.label}',
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.successLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        order.status == OrderStatus.completed
                            ? 'Pesanan sudah selesai (Lengkap).'
                            : 'Status pesanan tidak dapat diubah.',
                        style: const TextStyle(
                          color: AppColors.successText,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                SizedBox(height: 16 + bottomInset),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OrderPaymentBadge extends StatelessWidget {
  const _OrderPaymentBadge({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final payColor = AppColors.paymentStatus(order.paymentStatus, isDark: isDark);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: payColor.bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        order.paymentLabel,
        style: TextStyle(
          color: payColor.text,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
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
    final primary = Theme.of(context).colorScheme.primary;

    return Wrap(
      spacing: 6,
      runSpacing: 8,
      children: [
        for (var i = 0; i < stages.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: i == current
                  ? primary.withValues(alpha: 0.15)
                  : (i < current
                      ? AppColors.successLight
                      : Theme.of(context).cardColor),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: i == current
                    ? primary
                    : (i < current ? AppColors.success : Theme.of(context).dividerColor),
                width: i == current ? 1.5 : 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  i < current
                      ? Icons.check_circle
                      : (i == current ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                  size: 14,
                  color: i < current
                      ? AppColors.success
                      : (i == current ? primary : Theme.of(context).hintColor),
                ),
                const SizedBox(width: 4),
                Text(
                  stages[i].label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: i == current ? FontWeight.bold : FontWeight.w500,
                    color: i == current
                        ? primary
                        : (i < current ? AppColors.successText : null),
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
  late Fulfillment _value;
  late final TextEditingController _address;
  late final TextEditingController _fee;
  String? _error;

  @override
  void initState() {
    super.initState();
    final order = widget.order;
    _value = order.fulfillment;
    _address = TextEditingController(text: order.delivery?.address ?? '');
    final fee = order.delivery?.fee ?? 0;
    _fee = TextEditingController(text: fee == 0 ? '' : '$fee');
  }

  @override
  void dispose() {
    _address.dispose();
    _fee.dispose();
    super.dispose();
  }

  void _submit() {
    if (_value == Fulfillment.delivery && _address.text.trim().isEmpty) {
      setState(() => _error = 'Alamat pengantaran wajib diisi.');
      return;
    }
    Navigator.of(context).pop(
      _FulfillmentChoice(_value, _address.text.trim(), parseRupiah(_fee.text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ambil atau diantar?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FulfillmentFields(
              value: _value,
              onChanged: (v) => setState(() {
                _value = v;
                _error = null;
              }),
              address: _address,
              fee: _fee,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Simpan')),
      ],
    );
  }
}
