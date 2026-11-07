import 'package:flutter/material.dart';

import '../models/order.dart';
import '../models/order_option.dart';
import '../models/order_status.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';

class PriorityBadge extends StatelessWidget {
  const PriorityBadge({super.key, this.label = 'Same Day'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt, size: 13, color: AppColors.warningText),
          const SizedBox(width: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.warningText,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class FulfillmentBadge extends StatelessWidget {
  const FulfillmentBadge({super.key, required this.fulfillment});

  final Fulfillment fulfillment;

  @override
  Widget build(BuildContext context) {
    final delivery = fulfillment == Fulfillment.delivery;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          delivery ? Icons.delivery_dining : Icons.storefront_outlined,
          size: 15,
          color: AppColors.neutral,
        ),
        const SizedBox(width: 4),
        Text(
          fulfillment.label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }
}

class DueLabel extends StatelessWidget {
  const DueLabel({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final due = order.dueAt;
    if (due == null || order.status == OrderStatus.completed) {
      return const SizedBox.shrink();
    }
    final overdue = order.isOverdue;

    return Text(
      overdue
          ? 'Terlambat ${formatOverdue(due)}'
          : 'Tenggat ${formatDue(due)}',
      style: TextStyle(
        fontSize: 11,
        color: overdue ? AppColors.dangerText : AppColors.neutral,
        fontWeight: overdue ? FontWeight.bold : FontWeight.w500,
      ),
    );
  }
}
