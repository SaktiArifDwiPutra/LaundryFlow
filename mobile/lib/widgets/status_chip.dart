import 'package:flutter/material.dart';

import '../models/order_status.dart';
import '../theme/app_colors.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final OrderStatus status;

  IconData _statusIcon(OrderStatus s) {
    return switch (s) {
      OrderStatus.received => Icons.inventory_2_rounded,
      OrderStatus.washing => Icons.local_laundry_service_rounded,
      OrderStatus.drying => Icons.wb_sunny_rounded,
      OrderStatus.ironing => Icons.iron_rounded,
      OrderStatus.ready => Icons.check_circle_rounded,
      OrderStatus.outForDelivery => Icons.delivery_dining_rounded,
      OrderStatus.completed => Icons.verified_rounded,
      OrderStatus.unknown => Icons.help_outline_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = AppColors.stageStyle(status, isDark: isDark);
    final icon = _statusIcon(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: style.border, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: style.icon),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: TextStyle(
              color: style.text,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}
