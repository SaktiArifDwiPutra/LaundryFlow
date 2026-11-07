import 'package:flutter/material.dart';

import '../models/invoice.dart';
import '../repositories/repositories.dart';
import '../utils/format.dart';

class InvoiceSection extends StatefulWidget {
  const InvoiceSection({
    super.key,
    required this.orderId,
    this.onPaymentSuccess,
  });

  final int orderId;
  final VoidCallback? onPaymentSuccess;

  @override
  State<InvoiceSection> createState() => _InvoiceSectionState();
}

class _InvoiceSectionState extends State<InvoiceSection> {
  late Future<Invoice?> _future;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = invoiceRepository.getForOrder(widget.orderId);
    });
  }

  Future<void> _openPaymentDialog(Invoice invoice) async {
    String method = 'cash';
    final amountController = TextEditingController(
      text: invoice.amountDue > 0 ? '${invoice.amountDue}' : '${invoice.total}',
    );
    final refController = TextEditingController();
    final notesController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final enteredAmount = int.tryParse(
                amountController.text.replaceAll(RegExp(r'\D'), ''),
              ) ??
              0;
          final change = enteredAmount > invoice.amountDue && invoice.amountDue > 0
              ? enteredAmount - invoice.amountDue
              : (enteredAmount > invoice.total ? enteredAmount - invoice.total : 0);

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.point_of_sale, color: Colors.blue),
                SizedBox(width: 8),
                Text('Catat Pembayaran'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Total Tagihan: ${formatRupiah(invoice.total)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (invoice.amountDue > 0)
                    Text(
                      'Sisa Tagihan: ${formatRupiah(invoice.amountDue)}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: method,
                    decoration: const InputDecoration(
                      labelText: 'Metode Pembayaran',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'cash',
                        child: Text('Tunai (Cash)'),
                      ),
                      DropdownMenuItem(
                        value: 'qris',
                        child: Text('QRIS'),
                      ),
                      DropdownMenuItem(
                        value: 'transfer',
                        child: Text('Transfer Bank'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => method = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Nominal Bayar (Rp)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  if (change > 0 && method == 'cash') ...[
                    const SizedBox(height: 6),
                    Text(
                      'Kembalian: ${formatRupiah(change)}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: refController,
                    decoration: const InputDecoration(
                      labelText: 'No. Referensi (Opsional)',
                      hintText: 'Misal ID Transaksi QRIS/Bank',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Catatan Kasir (Opsional)',
                      border: OutlineInputBorder(),
                    ),
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
                icon: const Icon(Icons.check),
                label: const Text('Konfirmasi'),
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _processing = true);
    try {
      final nominal = int.tryParse(
        amountController.text.replaceAll(RegExp(r'\D'), ''),
      );
      await invoiceRepository.recordPayment(
        orderId: widget.orderId,
        paymentMethod: method,
        amountPaid: nominal,
        reference: refController.text.trim().isNotEmpty
            ? refController.text.trim()
            : null,
        notes: notesController.text.trim().isNotEmpty
            ? notesController.text.trim()
            : null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pembayaran berhasil dicatat.')),
      );
      _reload();
      widget.onPaymentSuccess?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mencatat pembayaran: $e')),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
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
            Text('Faktur & Pembayaran', style: Theme.of(context).textTheme.titleMedium),
            if (_processing)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 8),
        FutureBuilder<Invoice?>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              );
            }
            if (snapshot.hasError) {
              return Text('Gagal memuat invoice: ${snapshot.error}');
            }
            final invoice = snapshot.data;
            if (invoice == null) {
              return const Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Faktur belum diterbitkan untuk pesanan ini.'),
                ),
              );
            }

            final isPaid = invoice.isPaid;

            return Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.receipt_long, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                invoice.number.isEmpty
                                    ? 'Faktur #${invoice.id}'
                                    : invoice.number,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              if (invoice.paymentMethod.isNotEmpty)
                                Text(
                                  'Metode: ${invoice.methodLabel}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                        _PaymentChip(invoice: invoice),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Tagihan'),
                        Text(
                          formatRupiah(invoice.total),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    if (invoice.amountPaid > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Jumlah Dibayar'),
                          Text(formatRupiah(invoice.amountPaid)),
                        ],
                      ),
                    ],
                    if (invoice.amountDue > 0 && !isPaid) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Sisa Tagihan', style: TextStyle(color: Colors.red)),
                          Text(
                            formatRupiah(invoice.amountDue),
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (invoice.changeAmount > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Uang Kembalian', style: TextStyle(color: Colors.green)),
                          Text(
                            formatRupiah(invoice.changeAmount),
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (!isPaid) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonalIcon(
                          onPressed: _processing
                              ? null
                              : () => _openPaymentDialog(invoice),
                          icon: const Icon(Icons.payment, size: 18),
                          label: const Text('Catat Pembayaran di Kasir'),
                        ),
                      ),
                    ],
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

class _PaymentChip extends StatelessWidget {
  const _PaymentChip({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final color = invoice.isPaid
        ? Colors.green
        : (invoice.isPartial ? Colors.orange : Colors.red);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        invoice.paymentLabel,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
