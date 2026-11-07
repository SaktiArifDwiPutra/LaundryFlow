import 'package:flutter/material.dart';

import '../models/order.dart';
import '../models/order_option.dart';
import '../models/order_status.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import 'order_badges.dart';
import 'status_chip.dart';

class OrderTile extends StatelessWidget {
  const OrderTile({super.key, required this.order, required this.onTap});

  final Order order;
  final VoidCallback onTap;

  Color _accentColor(OrderStatus status) {
    return switch (status) {
      OrderStatus.ready => AppColors.success,
      OrderStatus.washing || OrderStatus.drying || OrderStatus.ironing => AppColors.primary,
      OrderStatus.outForDelivery => const Color(0xFF0D9488),
      OrderStatus.completed => AppColors.neutral,
      _ => const Color(0xFF64748B),
    };
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final payColor = AppColors.paymentStatus(order.paymentStatus, isDark: isDark);
    final accent = _accentColor(order.status);
    final isOverdue = order.isOverdue;

    final servicesSummary = order.lines.isEmpty
        ? 'Layanan Laundry'
        : order.lines.map((l) => '${formatQty(l.qty)} ${l.unit} ${l.serviceName}').join(', ');

    final customerInitial = order.customer.name.trim().isNotEmpty
        ? order.customer.name.trim()[0].toUpperCase()
        : 'P';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOverdue
              ? AppColors.danger.withValues(alpha: isDark ? 0.6 : 0.4)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: isOverdue ? 1.5 : 1.0,
        ),
        boxShadow: AppColors.cardShadow(isDark: isDark),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Customer Avatar + Name + Order Number + Total Price
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Avatar Monogram
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: isDark ? 0.22 : 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          customerInitial,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: accent,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Customer Name & Order #
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  order.customer.name.isEmpty
                                      ? 'Pelanggan Umum'
                                      : order.customer.name,
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (order.priority == OrderPriority.sameDay ||
                                  order.priority == OrderPriority.express) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning.withValues(alpha: isDark ? 0.25 : 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.bolt, size: 12, color: AppColors.warning),
                                      Text(
                                        'KILAT',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.warningText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkSurfaceElevated
                                  : AppColors.lightSurfaceElevated,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              order.number,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Big Friendly Amount
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatRupiah(order.total),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : AppColors.lightTextPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        // Mini Payment Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: payColor.bg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: payColor.text,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                order.paymentLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: payColor.text,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Services Summary Line
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurfaceElevated.withValues(alpha: 0.5)
                        : AppColors.lightSurfaceElevated.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.local_laundry_service_outlined,
                        size: 14,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          servicesSummary,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Bottom Status Pill + Due Time + Next Action
                Row(
                  children: [
                    StatusChip(status: order.status),
                    const Spacer(),
                    DueLabel(order: order),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
