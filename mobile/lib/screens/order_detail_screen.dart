import 'package:flutter/material.dart';
import '../widgets/invoice_section.dart';
import '../models/order.dart';
import '../models/order_status.dart';
import '../repositories/order_repository.dart';
import '../repositories/repositories.dart';
import '../utils/format.dart';
import '../widgets/status_chip.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final int orderId;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Future<Order> _future;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = orderRepository.get(widget.orderId);
  }

  Future<void> _advance(Order order) async {
    final next = order.status.next;
    if (next == null) return;

    setState(() => _saving = true);
    try {
      final updated = await orderRepository.advanceStatus(order.id, next);
      if (!mounted) return;
      setState(() {
        _future = Future.value(updated);
      });
    } on InvalidTransitionException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
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
          final next = order.status.next;

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
              const SizedBox(height: 24),
              InvoiceSection(
                key: ValueKey('${order.id}-${order.status.code}'),
                orderId: order.id,
              ),
              const SizedBox(height: 24),
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
              const Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total', style: textTheme.titleMedium),
                  Text(
                    formatRupiah(order.total),
                    style: textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (order.notes.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Catatan: ${order.notes}'),
              ],
              const SizedBox(height: 24),
              if (next != null) ...[
                FilledButton(
                  onPressed: _saving ? null : () => _advance(order),
                  child: Text(
                    _saving ? 'Menyimpan...' : 'Lanjut: ${next.label}',
                  ),
                ),
                if (next == OrderStatus.ready)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Di versi sungguhan, langkah ini membuat server mengirim notifikasi WhatsApp ke pelanggan.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
              ] else
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