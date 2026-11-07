import 'package:flutter/material.dart';

import '../models/invoice.dart';
import '../models/order.dart';
import '../repositories/repositories.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';

class InvoiceSection extends StatefulWidget {
  const InvoiceSection({
    super.key,
    required this.orderId,
    this.order,
    this.onPaymentSuccess,
  });

  final int orderId;
  final Order? order;
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
    final targetAmount = invoice.amountDue > 0 ? invoice.amountDue : invoice.total;
    final amountController = TextEditingController(text: '$targetAmount');
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
          final change = enteredAmount > targetAmount ? enteredAmount - targetAmount : 0;
          final deficit = enteredAmount < targetAmount && enteredAmount > 0 ? targetAmount - enteredAmount : 0;

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.point_of_sale, color: AppColors.primary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Catat Pembayaran Kasir',
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
                  // Total Bill Summary
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainerLight.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          invoice.amountDue > 0 ? 'Sisa Tagihan' : 'Total Tagihan',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          formatRupiah(targetAmount),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Method Segmented Chips
                  const Text('Metode Pembayaran', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Tunai'),
                          selected: method == 'cash',
                          onSelected: (_) => setDialogState(() => method = 'cash'),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('QRIS'),
                          selected: method == 'qris',
                          onSelected: (_) => setDialogState(() => method = 'qris'),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Transfer'),
                          selected: method == 'transfer',
                          onSelected: (_) => setDialogState(() => method = 'transfer'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Amount Input Field
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Nominal Bayar (Rp)',
                      prefixText: 'Rp ',
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),

                  // Quick Amount Chips for Cash
                  if (method == 'cash') ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ActionChip(
                          label: const Text('Uang Pas'),
                          onPressed: () {
                            setDialogState(() {
                              amountController.text = '$targetAmount';
                            });
                          },
                        ),
                        ActionChip(
                          label: const Text('Rp 20.000'),
                          onPressed: () {
                            setDialogState(() {
                              amountController.text = '20000';
                            });
                          },
                        ),
                        ActionChip(
                          label: const Text('Rp 50.000'),
                          onPressed: () {
                            setDialogState(() {
                              amountController.text = '50000';
                            });
                          },
                        ),
                        ActionChip(
                          label: const Text('Rp 100.000'),
                          onPressed: () {
                            setDialogState(() {
                              amountController.text = '100000';
                            });
                          },
                        ),
                      ],
                    ),
                  ],

                  // Change / Deficit Realtime Feedback
                  if (change > 0 && method == 'cash') ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.successLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Uang Kembalian:',
                            style: TextStyle(color: AppColors.successText, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            formatRupiah(change),
                            style: const TextStyle(
                              color: AppColors.successText,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (deficit > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.warningLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Bayar Sebagian (Kurang):',
                            style: TextStyle(color: AppColors.warningText, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            formatRupiah(deficit),
                            style: const TextStyle(
                              color: AppColors.warningText,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),
                  TextField(
                    controller: refController,
                    decoration: const InputDecoration(
                      labelText: 'No. Referensi (Opsional)',
                      hintText: 'Misal ID Transaksi QRIS / Bank',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Catatan Kasir (Opsional)',
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
                label: const Text('Konfirmasi Bayar'),
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
          ) ??
          targetAmount;
      await invoiceRepository.recordPayment(
        orderId: widget.orderId,
        paymentMethod: method,
        amountPaid: nominal > 0 ? nominal : targetAmount,
        reference: refController.text.trim().isNotEmpty
            ? refController.text.trim()
            : null,
        notes: notesController.text.trim().isNotEmpty
            ? notesController.text.trim()
            : null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pembayaran berhasil dicatat ke sistem.')),
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
            Text('Faktur & Pembayaran Kasir', style: Theme.of(context).textTheme.titleMedium),
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
            if (snapshot.connectionState != ConnectionState.done &&
                snapshot.data == null &&
                widget.order == null) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              );
            }
            if (snapshot.hasError && widget.order == null) {
              return Text('Gagal memuat invoice: ${snapshot.error}');
            }

            // Prefer fetched invoice, fallback to synthesized invoice from order details
            final invoice = snapshot.data ??
                (widget.order != null
                    ? Invoice(
                        id: widget.order!.id,
                        orderId: widget.order!.id,
                        orderNumber: widget.order!.number,
                        number: 'INV-${widget.order!.number}',
                        state: 'posted',
                        paymentState: widget.order!.paymentStatus,
                        total: widget.order!.total,
                        amountPaid: widget.order!.amountPaid,
                        amountDue: widget.order!.amountDue > 0
                            ? widget.order!.amountDue
                            : (widget.order!.isPaid ? 0 : widget.order!.total),
                        changeAmount: 0,
                        paymentMethod: widget.order!.paymentMethod,
                        currency: widget.order!.currency,
                      )
                    : null);

            if (invoice == null) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('Faktur belum diterbitkan untuk pesanan ini.'),
                ),
              );
            }

            final isPaid = invoice.isPaid;

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.receipt_long, color: AppColors.primary),
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
                    const Divider(height: 24),
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
                          const Text('Sisa Tagihan', style: TextStyle(color: AppColors.dangerText)),
                          Text(
                            formatRupiah(invoice.amountDue),
                            style: const TextStyle(
                              color: AppColors.dangerText,
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
                          const Text('Uang Kembalian', style: TextStyle(color: AppColors.successText)),
                          Text(
                            formatRupiah(invoice.changeAmount),
                            style: const TextStyle(
                              color: AppColors.successText,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (!isPaid) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: _processing
                              ? null
                              : () => _openPaymentDialog(invoice),
                          icon: const Icon(Icons.point_of_sale, size: 18),
                          label: const Text('Catat Pembayaran Kasir'),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final payColor = AppColors.paymentStatus(invoice.paymentState, isDark: isDark);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: payColor.bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        invoice.paymentLabel,
        style: TextStyle(
          color: payColor.text,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
