import 'package:flutter/material.dart';

import '../api/api_exception.dart';
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
    } on ApiException catch (e) {
      _toast(e.message);
    } catch (e) {
      _toast('Gagal mengubah pengantaran: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildSectionHeader(IconData icon, String title, Color color) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
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
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: AppColors.danger,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Gagal memuat pesanan: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: const Icon(Icons.refresh_rounded),
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
        final payColor =
            AppColors.paymentStatus(order.paymentStatus, isDark: isDark);
        final stageStyle = AppColors.stageStyle(order.status, isDark: isDark);
        final customerName = order.customer.name.isEmpty
            ? 'Pelanggan Umum'
            : order.customer.name;
        final avatarStyle = AppColors.avatarStyle(customerName, isDark: isDark);

        return Scaffold(
          appBar: AppBar(
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: AppColors.heroGradient(isDark: isDark),
              ),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        order.number,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: payColor.bg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: payColor.border),
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
                  customerName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFDBEAFE),
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Muat Ulang',
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                onPressed: _reload,
              ),
              const SizedBox(width: 4),
            ],
          ),

          // Pinned Bottom Action Bar for Next Stage Transition
          bottomNavigationBar: (next != null)
              ? Container(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomInset),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    border: Border(
                      top: BorderSide(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                        width: 1.2,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? const Color(0x55000000)
                            : const Color(0x141E40AF),
                        blurRadius: 18,
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
                              'TAHAP SELANJUTNYA',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.neutral,
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              next.label,
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                                color: next == OrderStatus.ready
                                    ? AppColors.teal
                                    : (isDark
                                        ? Colors.white
                                        : AppColors.primaryDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: next == OrderStatus.ready
                              ? AppColors.tealGradient
                              : AppColors.primaryActionGradient,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: AppColors.glowShadow(
                            next == OrderStatus.ready
                                ? AppColors.teal
                                : AppColors.primaryBright,
                            isDark: isDark,
                          ),
                        ),
                        child: FilledButton(
                          onPressed: _saving ? null : () => _advance(order),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            minimumSize: const Size(168, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
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
                                      next == OrderStatus.ready
                                          ? Icons.check_circle_rounded
                                          : Icons.arrow_forward_rounded,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      next == OrderStatus.ready
                                          ? 'Siap Diambil'
                                          : 'Lanjut Status',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                )
              : null,

          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              // 1. Hero Status & Timeline Card with Colored Top Accent
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: stageStyle.icon.withValues(alpha: isDark ? 0.55 : 0.4),
                    width: 1.5,
                  ),
                  boxShadow: AppColors.cardShadow(isDark: isDark),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(17),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: stageStyle.bg,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  StatusChip(status: order.status),
                                  if (order.priority == OrderPriority.express ||
                                      order.priority == OrderPriority.sameDay)
                                    PriorityBadge(label: order.priority.label),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              flex: 0,
                              child: DueLabel(order: order),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'WAKTU MASUK NOTA',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.neutral,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${order.createdAt.day.toString().padLeft(2, '0')}/${order.createdAt.month.toString().padLeft(2, '0')}/${order.createdAt.year} • ${order.createdAt.hour.toString().padLeft(2, '0')}:${order.createdAt.minute.toString().padLeft(2, '0')}',
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                FulfillmentBadge(
                                  fulfillment: order.fulfillment,
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            const Divider(height: 1),
                            const SizedBox(height: 12),
                            const Text(
                              'ALUR TAHAPAN CUCIAN',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.neutral,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _StageProgress(order: order),
                          ],
                        ),
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
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.danger.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.alarm_on_rounded,
                        color: AppColors.danger,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Pesanan ini terlambat ${formatOverdue(due)} dari tenggat waktu.',
                          style: const TextStyle(
                            color: AppColors.dangerText,
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),

              // 2. Customer & Fulfillment Combined Section
              _buildSectionHeader(
                Icons.person_pin_rounded,
                'Pelanggan & Pengantaran',
                AppColors.indigo,
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    width: 1.2,
                  ),
                  boxShadow: AppColors.cardShadow(isDark: isDark),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: avatarStyle.bg,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(
                              child: Text(
                                customerName[0].toUpperCase(),
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: avatarStyle.text,
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
                                  customerName,
                                  style: const TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.phone_iphone_rounded,
                                      size: 14,
                                      color: AppColors.teal,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      order.customer.phone.isEmpty
                                          ? 'Tidak ada nomor telepon'
                                          : order.customer.phone,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
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
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: (order.fulfillment == Fulfillment.delivery
                                      ? AppColors.cyan
                                      : AppColors.teal)
                                  .withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              order.fulfillment == Fulfillment.delivery
                                  ? Icons.delivery_dining_rounded
                                  : Icons.storefront_rounded,
                              size: 18,
                              color: order.fulfillment == Fulfillment.delivery
                                  ? AppColors.cyan
                                  : AppColors.teal,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  order.fulfillment == Fulfillment.delivery
                                      ? 'Pengantaran ke Alamat'
                                      : 'Ambil Sendiri di Toko',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                  ),
                                ),
                                if (delivery != null &&
                                    delivery.address.isNotEmpty)
                                  Text(
                                    delivery.address,
                                    style: textTheme.bodySmall,
                                  ),
                                if (deliveryFee > 0)
                                  Text(
                                    'Ongkos Kirim: ${formatRupiah(deliveryFee)}',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.cyan,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (canEditFulfillment)
                            OutlinedButton.icon(
                              onPressed: _saving
                                  ? null
                                  : () => _editFulfillment(order),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(74, 34),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(9),
                                ),
                              ),
                              icon: const Icon(Icons.edit_outlined, size: 14),
                              label: const Text(
                                'Ubah',
                                style: TextStyle(fontSize: 11.5),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // 3. Itemized Receipt Card (Commercial POS Nota)
              _buildSectionHeader(
                Icons.receipt_rounded,
                'Rincian Layanan & Biaya Nota',
                AppColors.primaryBright,
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    width: 1.2,
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
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryBright
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: const Icon(
                                  Icons.local_laundry_service_rounded,
                                  size: 16,
                                  color: AppColors.primaryBright,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      line.serviceName,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      '${formatQty(line.qty)} ${line.unit} × ${formatRupiah(line.unitPrice)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? AppColors.darkTextSecondary
                                            : AppColors.lightTextSecondary,
                                      ),
                                    ),
                                    if (line.itemDetails.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          'Rincian: ${line.itemDetails}',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontStyle: FontStyle.italic,
                                            color: isDark
                                                ? AppColors.darkTextMuted
                                                : AppColors.lightTextMuted,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Text(
                                formatRupiah(line.subtotal),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 14),
                      ],
                      const SizedBox(height: 4),
                      _MoneyRow(
                        label: 'Subtotal Layanan',
                        value: formatRupiah(servicesTotal),
                      ),
                      if (order.expressFee > 0)
                        _MoneyRow(
                          label: 'Biaya Kilat / Same Day',
                          value: '+ ${formatRupiah(order.expressFee)}',
                          valueColor: AppColors.warmOrange,
                        ),
                      if (deliveryFee > 0)
                        _MoneyRow(
                          label: 'Ongkos Kirim',
                          value: '+ ${formatRupiah(deliveryFee)}',
                          valueColor: AppColors.cyan,
                        ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurfaceElevated
                              : AppColors.lightSurfaceElevated,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Keseluruhan',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              formatRupiah(order.total),
                              style: TextStyle(
                                fontSize: 18.5,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? Colors.white
                                    : AppColors.primaryDark,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (order.notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.violetDark.withValues(alpha: 0.35)
                        : AppColors.violetLight.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.violet.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.sticky_note_2_rounded,
                        size: 18,
                        color: AppColors.violet,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Catatan Pesanan: ${order.notes}',
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // 4. Invoice & Payment Section
              InvoiceSection(
                key: ValueKey(
                  '${order.id}-${order.status.code}-${order.paymentStatus}-${order.amountPaid}',
                ),
                orderId: order.id,
                order: order,
                onPaymentSuccess: _reload,
              ),
              const SizedBox(height: 20),

              // 5. WhatsApp Notification Section
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
  const _MoneyRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(
            value,
            style: style?.copyWith(
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Wrap(
      spacing: 6,
      runSpacing: 8,
      children: [
        for (var i = 0; i < stages.length; i++)
          Builder(
            builder: (context) {
              final stageStyle =
                  AppColors.stageStyle(stages[i], isDark: isDark);
              final isCurrent = i == current;
              final isDone = i < current;

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5.5,
                ),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? stageStyle.bg
                      : (isDone
                          ? (isDark
                              ? AppColors.tealDark.withValues(alpha: 0.45)
                              : AppColors.tealLight)
                          : (isDark
                              ? AppColors.darkSurfaceElevated
                              : AppColors.lightSurfaceElevated)),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: isCurrent
                        ? stageStyle.icon
                        : (isDone
                            ? AppColors.teal.withValues(alpha: 0.45)
                            : (isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder)),
                    width: isCurrent ? 1.8 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isDone) ...[
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 13,
                        color: AppColors.teal,
                      ),
                      const SizedBox(width: 4),
                    ] else if (isCurrent) ...[
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: stageStyle.icon,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      stages[i].label,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight:
                            isCurrent ? FontWeight.w800 : FontWeight.w600,
                        color: isCurrent
                            ? stageStyle.text
                            : (isDone
                                ? (isDark ? AppColors.tealGlow : AppColors.teal)
                                : AppColors.neutral),
                      ),
                    ),
                  ],
                ),
              );
            },
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
      title: const Row(
        children: [
          Icon(Icons.delivery_dining_rounded, color: AppColors.cyan),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Ubah Pengantaran',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<Fulfillment>(
              segments: const [
                ButtonSegment(
                  value: Fulfillment.pickup,
                  label: Text('Ambil Toko'),
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
                _fulfillment == Fulfillment.delivery
                    ? _address.text.trim()
                    : '',
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
