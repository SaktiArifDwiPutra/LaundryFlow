import 'package:flutter/material.dart';

import '../models/invoice.dart';
import '../repositories/repositories.dart';
import '../utils/format.dart';

class InvoiceSection extends StatefulWidget {
  const InvoiceSection({super.key, required this.orderId});

  final int orderId;

  @override
  State<InvoiceSection> createState() => _InvoiceSectionState();
}

class _InvoiceSectionState extends State<InvoiceSection> {
  late final Future<Invoice?> _future;

  @override
  void initState() {
    super.initState();
    _future = invoiceRepository.getForOrder(widget.orderId);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Invoice', style: Theme.of(context).textTheme.titleMedium),
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
              return const Text('Invoice belum dibuat.');
            }
            return Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.receipt_long),
                title: Text(invoice.number),
                subtitle: Text(
                  '${invoice.stateLabel} • ${formatRupiah(invoice.total)}',
                ),
                trailing: _PaymentChip(invoice: invoice),
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
        : invoice.paymentState == 'not_paid'
            ? Colors.orange
            : Colors.grey;

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