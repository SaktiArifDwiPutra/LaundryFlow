import 'package:flutter/material.dart';

import '../models/order.dart';
import '../models/order_option.dart';
import '../models/order_status.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import 'order_badges.dart';
import 'status_chip.dart';

/// Perforated Commercial POS Ticket Card (Stitch Direction B/C Hybrid)
class OrderTile extends StatelessWidget {
  const OrderTile({super.key, required this.order, required this.onTap});

  final Order order;
  final VoidCallback onTap;

  Color _statusBarColor(OrderStatus status) {
    return switch (status) {
      OrderStatus.received => AppColors.indigo,
      OrderStatus.washing => AppColors.primaryBright,
      OrderStatus.drying => AppColors.cyanBright,
      OrderStatus.ironing => AppColors.violet,
      OrderStatus.ready => AppColors.teal,
      OrderStatus.outForDelivery => AppColors.warmOrangeBright,
      OrderStatus.completed => AppColors.success,
      OrderStatus.unknown => AppColors.danger,
    };
  }

  String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'P';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return trimmed[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final payColor = AppColors.paymentStatus(order.paymentStatus, isDark: isDark);
    final barColor = _statusBarColor(order.status);
    final isOverdue = order.isOverdue;
    final customerName = order.customer.name.isEmpty ? 'Pelanggan Umum' : order.customer.name;
    final avatarStyle = AppColors.avatarStyle(customerName, isDark: isDark);

    final servicesSummary = order.lines.isEmpty
        ? 'Layanan Laundry Reguler'
        : order.lines
            .map((l) => '${formatQty(l.qty)} ${l.unit} ${l.serviceName}')
            .join(' • ');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isOverdue
              ? AppColors.danger.withValues(alpha: isDark ? 0.75 : 0.55)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: isOverdue ? 1.8 : 1.2,
        ),
        boxShadow: AppColors.cardShadow(isDark: isDark),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Thick Semantic Left Status Bar
              Container(
                width: 6,
                decoration: BoxDecoration(
                  color: barColor,
                ),
              ),

              // 2. Perforated Ticket Content
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTap,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Zone 1: Ticket Header Row (#LDR/... + Express/Delivery + StatusChip)
                          Row(
                            children: [
                              // Order Number Monospace Pill
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.darkSurfaceElevated
                                      : AppColors.lightSurfaceElevated,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.confirmation_number_outlined,
                                      size: 12,
                                      color: isDark
                                          ? AppColors.primaryLight
                                          : AppColors.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      order.number,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        color: isDark
                                            ? AppColors.darkTextPrimary
                                            : AppColors.primaryDark,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              if (order.priority == OrderPriority.sameDay ||
                                  order.priority == OrderPriority.express) ...[
                                const SizedBox(width: 6),
                                const PriorityBadge(label: 'Kilat'),
                              ],

                              if (order.fulfillment == Fulfillment.delivery) ...[
                                const SizedBox(width: 6),
                                const FulfillmentBadge(
                                  fulfillment: Fulfillment.delivery,
                                ),
                              ],

                              const Spacer(),
                              StatusChip(status: order.status),
                            ],
                          ),

                          const SizedBox(height: 11),

                          // Zone 2: Customer Profile + Service Breakdown
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Customer Avatar Circle
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: avatarStyle.bg,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    _initials(customerName),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: avatarStyle.text,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 11),

                              // Customer Name & Service Summary
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            customerName,
                                            style: textTheme.titleMedium?.copyWith(
                                              fontSize: 15.5,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: -0.2,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (order.customer.phone.isNotEmpty) ...[
                                          const SizedBox(width: 6),
                                          Text(
                                            '• ${order.customer.phone}',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: isDark
                                                  ? AppColors.darkTextMuted
                                                  : AppColors.lightTextMuted,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.layers_outlined,
                                          size: 13,
                                          color: isDark
                                              ? AppColors.darkTextSecondary
                                              : AppColors.lightTextSecondary,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            servicesSummary,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
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
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 11),

                          // Perforated Ticket Divider Line
                          CustomPaint(
                            size: const Size(double.infinity, 1),
                            painter: _DashedLinePainter(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder,
                            ),
                          ),

                          const SizedBox(height: 10),

                          // Zone 3: Financial Total + Payment Status + Due/Action Footer
                          Row(
                            children: [
                              // Order Total Price (Tabular Figures)
                              Text(
                                formatRupiah(order.total),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.primaryDark,
                                  letterSpacing: -0.4,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Payment Status Pill
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: payColor.bg,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: payColor.border,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      order.isPaid
                                          ? Icons.verified_rounded
                                          : Icons.payments_outlined,
                                      size: 11.5,
                                      color: payColor.icon,
                                    ),
                                    const SizedBox(width: 3.5),
                                    Text(
                                      order.paymentLabel,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        color: payColor.text,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const Spacer(),

                              // Due Label / Overdue Warning
                              DueLabel(order: order),

                              const SizedBox(width: 6),
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.darkSurfaceElevated
                                      : AppColors.lightSurfaceElevated,
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 11,
                                  color: isDark
                                      ? AppColors.primaryLight
                                      : AppColors.primary,
                                ),
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

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    const dashWidth = 5.0;
    const dashSpace = 4.0;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, 0),
        Offset((startX + dashWidth).clamp(0.0, size.width), 0),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}
