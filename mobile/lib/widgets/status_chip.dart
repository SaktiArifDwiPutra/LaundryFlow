import 'package:flutter/material.dart';

import '../models/order_status.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final OrderStatus status;

  Color get _color => switch (status) {
        OrderStatus.received => Colors.blueGrey,
        OrderStatus.washing => Colors.blue,
        OrderStatus.drying => Colors.orange,
        OrderStatus.ironing => Colors.deepPurple,
        OrderStatus.ready => Colors.green,
        OrderStatus.outForDelivery => Colors.teal,
        OrderStatus.completed => Colors.grey,
        OrderStatus.unknown => Colors.red,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: _color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}