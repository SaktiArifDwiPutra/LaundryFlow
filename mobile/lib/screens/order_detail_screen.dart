import 'package:flutter/material.dart';

import '../models/order.dart';
import '../models/order_option.dart';
import '../models/order_status.dart';
import '../repositories/order_repository.dart';
import '../repositories/repositories.dart';
import '../utils/format.dart';
import '../widgets/fulfillment_fields.dart';
import '../widgets/invoice_section.dart';
import '../widgets/order_badges.dart';
import '../widgets/status_chip.dart';

/// Hasil dialog "Ambil atau diantar?".
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
            child: const Text('Ya, ubah'),
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

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Pesanan')),
      body: FutureBuilder<Order>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Gagal memuat pesanan: ${snapshot.error}'),
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
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(order.number, style: textTheme.titleLarge),
                  ),
                  StatusChip(status: order.status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (order.priority == OrderPriority.express) ...[
                    const PriorityBadge(),
                    const SizedBox(width: 8),
                  ],
                  FulfillmentBadge(fulfillment: order.fulfillment),
                  const Spacer(),
                  DueLabel(order: order),
                ],
              ),
              if (order.isOverdue && due != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Pesanan ini terlambat ${formatOverdue(due)} dari tenggat.',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _StageProgress(order: order),
              const Divider(height: 32),
              Text(order.customer.name, style: textTheme.titleMedium),
              Text(order.customer.phone.isEmpty ? '-' : order.customer.phone),
              const SizedBox(height: 16),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Pengambilan',
                              style: textTheme.titleMedium,
                            ),
                          ),
                          if (canEditFulfillment)
                            TextButton(
                              onPressed:
                                  _saving ? null : () => _editFulfillment(order),
                              child: const Text('Ubah'),
                            ),
                        ],
                      ),
                      Text(
                        order.fulfillment == Fulfillment.delivery
                            ? 'Diantar kurir toko'
                            : 'Diambil sendiri oleh pelanggan',
                      ),
                      if (delivery != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Alamat: ${delivery.address.isEmpty ? '-' : delivery.address}',
                        ),
                        if (deliveryFee > 0)
                          Text('Ongkir: ${formatRupiah(deliveryFee)}'),
                        if (delivery.courierName != null)
                          Text('Kurir: ${delivery.courierName}'),
                      ],
                    ],
                  ),
                ),
              ),
              const Divider(height: 32),
              for (final line in order.lines)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(line.serviceName),
                  subtitle: Text(
                    '${formatQty(line.qty)} ${line.unit} × ${formatRupiah(line.unitPrice)}',
                  ),
                  trailing: Text(formatRupiah(line.subtotal)),
                ),
              const Divider(height: 24),
              _MoneyRow(label: 'Layanan', value: formatRupiah(servicesTotal)),
              if (order.expressFee > 0)
                _MoneyRow(
                  label: 'Biaya Express',
                  value: formatRupiah(order.expressFee),
                ),
              if (deliveryFee > 0)
                _MoneyRow(label: 'Ongkir', value: formatRupiah(deliveryFee)),
              _MoneyRow(
                label: 'Total',
                value: formatRupiah(order.total),
                bold: true,
              ),
              if (order.notes.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Catatan: ${order.notes}'),
              ],
              const SizedBox(height: 24),
              InvoiceSection(
                key: ValueKey('${order.id}-${order.status.code}'),
                orderId: order.id,
              ),
              const SizedBox(height: 24),
              if (next != null)
                FilledButton(
                  onPressed: _saving ? null : () => _advance(order),
                  child: Text(
                    _saving ? 'Menyimpan...' : 'Lanjut: ${next.label}',
                  ),
                )
              else
                Text(
                  order.status == OrderStatus.completed
                      ? 'Pesanan sudah selesai.'
                      : 'Status tidak dikenal, tidak bisa diubah dari aplikasi.',
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({required this.label, required this.value, this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold)
        : Theme.of(context).textTheme.bodyMedium;
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
      runSpacing: 6,
      children: [
        for (var i = 0; i < stages.length; i++)
          Chip(
            visualDensity: VisualDensity.compact,
            avatar: Icon(
              i < current
                  ? Icons.check_circle
                  : i == current
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
              size: 16,
              color: i <= current ? primary : null,
            ),
            label: Text(
              stages[i].label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: i == current ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
      ],
    );
  }
}

/// Dialog ubah pilihan ambil/antar. Pemilik controller-nya dialog ini sendiri,
/// jadi dibuang dengan benar saat dialog tertutup.
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