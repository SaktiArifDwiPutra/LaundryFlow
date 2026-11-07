import 'package:flutter/material.dart';

import '../models/order.dart';
import '../models/order_option.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import 'order_badges.dart';
import 'status_chip.dart';

class OrderTile extends StatelessWidget {
  const OrderTile({super.key, required this.order, required this.onTap});

  final Order order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final payColor = AppColors.paymentStatus(order.paymentStatus, isDark: isDark);

    final servicesSummary = order.lines.isEmpty
        ? 'Layanan Laundry'
        : order.lines.map((l) => '${formatQty(l.qty)} ${l.unit} ${l.serviceName}').join(', ');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Customer Name & Order Total
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.customer.name.isEmpty ? 'Pelanggan Umum' : order.customer.name,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          order.number,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.primaryLight : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatRupiah(order.total),
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Subtitle: Services Summary
              Text(
                servicesSummary,
                style: textTheme.bodySmall?.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),

              // Badges Row
              Row(
                children: [
                  // Payment Status Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: payColor.bg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          order.isPaid
                              ? Icons.check_circle
                              : (order.isPartial ? Icons.pie_chart : Icons.schedule),
                          size: 13,
                          color: payColor.icon,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          order.paymentLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: payColor.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Workflow Status Chip
                  StatusChip(status: order.status),
                  const Spacer(),

                  // Due / Overdue Label
                  DueLabel(order: order),
                ],
              ),

              // Bottom Details Row (if express/sameday or delivery)
              if (order.priority == OrderPriority.sameDay ||
                  order.priority == OrderPriority.express ||
                  order.fulfillment == Fulfillment.delivery) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (order.priority == OrderPriority.sameDay ||
                        order.priority == OrderPriority.express) ...[
                      PriorityBadge(label: order.priority.label),
                      const SizedBox(width: 8),
                    ],
                    FulfillmentBadge(fulfillment: order.fulfillment),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
