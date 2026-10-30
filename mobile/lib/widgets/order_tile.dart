import 'package:flutter/material.dart';

import '../models/order.dart';
import '../models/order_option.dart';
import 'order_badges.dart';
import 'status_chip.dart';

class OrderTile extends StatelessWidget {
  const OrderTile({super.key, required this.order, required this.onTap});

  final Order order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final first = order.lines.isEmpty ? '-' : order.lines.first.serviceName;
    final more = order.lines.length > 1 ? ' +${order.lines.length - 1}' : '';

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
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(order.customer.name, style: textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          '${order.number} • $first$more',
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  StatusChip(status: order.status),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (order.priority == OrderPriority.express || order.priority == OrderPriority.sameDay) ...[
                    PriorityBadge(label: order.priority.label),
                    const SizedBox(width: 8),
                  ],
                  FulfillmentBadge(fulfillment: order.fulfillment),
                  const Spacer(),
                  DueLabel(order: order),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}