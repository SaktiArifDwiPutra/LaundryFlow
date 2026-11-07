import 'package:flutter/material.dart';

import '../models/order.dart';
import '../models/order_option.dart';
import '../models/order_status.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import 'order_badges.dart';

/// Modern bespoke Order Card inspired by Super Clean POS & modern SaaS aesthetics
class OrderTile extends StatelessWidget {
  const OrderTile({super.key, required this.order, required this.onTap});

  final Order order;
  final VoidCallback onTap;

  Color _statusAccent(OrderStatus status) {
    return switch (status) {
      OrderStatus.ready => AppColors.success,
      OrderStatus.washing => const Color(0xFF2563EB), // Vibrant Blue
      OrderStatus.drying => const Color(0xFFF59E0B), // Warm Amber
      OrderStatus.ironing => const Color(0xFF8B5CF6), // Purple
      OrderStatus.outForDelivery => const Color(0xFF0D9488), // Teal
      OrderStatus.completed => AppColors.neutral,
      _ => const Color(0xFF64748B),
    };
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final payColor = AppColors.paymentStatus(order.paymentStatus, isDark: isDark);
    final accent = _statusAccent(order.status);
    final isOverdue = order.isOverdue;

    final servicesSummary = order.lines.isEmpty
        ? 'Layanan Laundry'
        : order.lines.map((l) => '${formatQty(l.qty)} ${l.unit} ${l.serviceName}').join(', ');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4.5),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOverdue
              ? AppColors.danger.withValues(alpha: isDark ? 0.7 : 0.45)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: isOverdue ? 1.5 : 1.0,
        ),
        boxShadow: AppColors.cardShadow(isDark: isDark),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Bespoke Left Status Accent Bar (Inspired by Super Clean Dribbble ref)
              Container(
                width: 4.5,
                color: accent,
              ),

              // 2. Card Content
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTap,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Row 1: Customer Name & Status Pill
                          Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        order.customer.name.isEmpty
                                            ? 'Pelanggan Umum'
                                            : order.customer.name,
                                        style: textTheme.titleMedium?.copyWith(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (order.priority == OrderPriority.sameDay ||
                                        order.priority == OrderPriority.express) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 1.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.warning.withValues(
                                            alpha: isDark ? 0.25 : 0.14,
                                          ),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.bolt,
                                              size: 11,
                                              color: AppColors.warning,
                                            ),
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
                              ),
                              const SizedBox(width: 8),

                              // Clean Modern Status Pill
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2.5,
                                ),
                                decoration: BoxDecoration(
                                  color: accent.withValues(
                                    alpha: isDark ? 0.22 : 0.10,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 5,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color: accent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      order.status.label,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : accent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 5),

                          // Row 2: Order ID tag + Services list
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1.5,
                                ),
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
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  servicesSummary,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 9),

                          // Row 3: Price + Payment Status + Due / Delivery
                          Row(
                            children: [
                              // Order Total Price
                              Text(
                                formatRupiah(order.total),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.lightTextPrimary,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Payment Status Badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: payColor.bg,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  order.paymentLabel,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: payColor.text,
                                  ),
                                ),
                              ),

                              const Spacer(),

                              // Due Label or Overdue
                              DueLabel(order: order),

                              const SizedBox(width: 4),
                              Icon(
                                Icons.chevron_right,
                                size: 16,
                                color: isDark
                                    ? AppColors.darkTextMuted
                                    : AppColors.lightTextMuted,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
