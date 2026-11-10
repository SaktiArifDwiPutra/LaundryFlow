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
    final targetAmount =
        invoice.amountDue > 0 ? invoice.amountDue : invoice.total;
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
          final change =
              enteredAmount > targetAmount ? enteredAmount - targetAmount : 0;
          final deficit = enteredAmount < targetAmount && enteredAmount > 0
              ? targetAmount - enteredAmount
              : 0;

          return AlertDialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.point_of_sale_rounded, color: AppColors.primaryBright),
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
                      color: AppColors.primaryContainerLight.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primaryBright.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          invoice.amountDue > 0
                              ? 'Sisa Tagihan'
                              : 'Total Tagihan',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        Text(
                          formatRupiah(targetAmount),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Method Segmented Chips
                  const Text(
                    'Metode Pembayaran',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Tunai'),
                          selected: method == 'cash',
                          onSelected: (_) =>
                              setDialogState(() => method = 'cash'),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('QRIS'),
                          selected: method == 'qris',
                          onSelected: (_) =>
                              setDialogState(() => method = 'qris'),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Transfer'),
                          selected: method == 'transfer',
                          onSelected: (_) =>
                              setDialogState(() => method = 'transfer'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Amount Input Field
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontWeight: FontWeight.w800),
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
                          visualDensity: VisualDensity.compact,
                          label: const Text('Uang Pas'),
                          onPressed: () {
                            setDialogState(() {
                              amountController.text = '$targetAmount';
                            });
                          },
                        ),
                        ActionChip(
                          visualDensity: VisualDensity.compact,
                          label: const Text('Rp 20.000'),
                          onPressed: () {
                            setDialogState(() {
                              amountController.text = '20000';
                            });
                          },
                        ),
                        ActionChip(
                          visualDensity: VisualDensity.compact,
                          label: const Text('Rp 50.000'),
                          onPressed: () {
                            setDialogState(() {
                              amountController.text = '50000';
                            });
                          },
                        ),
                        ActionChip(
                          visualDensity: VisualDensity.compact,
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.successLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Uang Kembalian:',
                            style: TextStyle(
                              color: AppColors.successText,
                              fontWeight: FontWeight.w800,
                            ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warmOrangeLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Bayar Sebagian (Kurang):',
                            style: TextStyle(
                              color: AppColors.warmOrange,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            formatRupiah(deficit),
                            style: const TextStyle(
                              color: AppColors.warmOrange,
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
                icon: const Icon(Icons.check_circle_rounded, size: 18),
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
        const SnackBar(
          content: Text('Pembayaran berhasil dicatat ke sistem.'),
        ),
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
                    Icons.point_of_sale_rounded,
                    size: 15,
                    color: AppColors.teal,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Faktur & Pembayaran Kasir',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
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
            final payStyle =
                AppColors.paymentStatus(invoice.paymentState, isDark: isDark);

            return Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isPaid
                      ? AppColors.teal.withValues(alpha: isDark ? 0.55 : 0.4)
                      : AppColors.warmOrange
                          .withValues(alpha: isDark ? 0.55 : 0.4),
                  width: 1.5,
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
                            color: payStyle.bg,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Icon(
                            isPaid
                                ? Icons.verified_rounded
                                : Icons.receipt_long_rounded,
                            color: payStyle.icon,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                invoice.number.isEmpty
                                    ? 'Faktur #${invoice.id}'
                                    : invoice.number,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14.5,
                                ),
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
                    const Divider(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Tagihan Faktur',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          formatRupiah(invoice.total),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    if (invoice.amountPaid > 0) ...[
                      const SizedBox(height: 5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Jumlah Dibayar'),
                          Text(
                            formatRupiah(invoice.amountPaid),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ],
                    if (invoice.amountDue > 0 && !isPaid) ...[
                      const SizedBox(height: 5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Sisa Tagihan',
                            style: TextStyle(
                              color: AppColors.dangerText,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            formatRupiah(invoice.amountDue),
                            style: const TextStyle(
                              color: AppColors.dangerText,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (invoice.changeAmount > 0) ...[
                      const SizedBox(height: 5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Uang Kembalian',
                            style: TextStyle(color: AppColors.successText),
                          ),
                          Text(
                            formatRupiah(invoice.changeAmount),
                            style: const TextStyle(
                              color: AppColors.successText,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (!isPaid) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryActionGradient,
                          borderRadius: BorderRadius.circular(13),
                          boxShadow: AppColors.glowShadow(
                            AppColors.primaryBright,
                            isDark: isDark,
                          ),
                        ),
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                          ),
                          onPressed: _processing
                              ? null
                              : () => _openPaymentDialog(invoice),
                          icon: const Icon(
                            Icons.point_of_sale_rounded,
                            size: 18,
                          ),
                          label: const Text(
                            'Catat Pembayaran Kasir',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
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
    final payColor =
        AppColors.paymentStatus(invoice.paymentState, isDark: isDark);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(
        color: payColor.bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: payColor.border),
      ),
      child: Text(
        invoice.paymentLabel,
        style: TextStyle(
          color: payColor.text,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
