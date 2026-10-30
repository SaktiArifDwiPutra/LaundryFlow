import 'package:flutter/material.dart';

import '../models/order.dart';
import '../models/order_option.dart';
import '../models/order_status.dart';
import '../utils/format.dart';

class PriorityBadge extends StatelessWidget {
  const PriorityBadge({super.key, this.label = 'Same Day'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt, size: 14, color: Colors.orange),
          const SizedBox(width: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.orange,
              fontSize: 12,
              fontWeight: FontWeight.w600,
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
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(fulfillment.label, style: Theme.of(context).textTheme.bodySmall),
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
    final Color? color =
        overdue ? Colors.red : Theme.of(context).textTheme.bodySmall?.color;

    return Text(
      overdue
          ? 'Terlambat ${formatOverdue(due)}'
          : 'Tenggat ${formatDue(due)}',
      style: TextStyle(
        fontSize: 12,
        color: color,
        fontWeight: overdue ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}