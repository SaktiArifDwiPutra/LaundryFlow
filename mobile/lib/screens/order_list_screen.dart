import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../models/order.dart';
import '../models/order_status.dart';
import '../utils/format.dart';

class OrderListScreen extends StatelessWidget {
  const OrderListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final orders = mockOrders;

    return Scaffold(
      appBar: AppBar(title: const Text('Pesanan')),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: orders.length,
        itemBuilder: (context, index) => _OrderCard(order: orders[index]),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final service =
        order.lines.isEmpty ? '-' : order.lines.first.serviceName;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.customer.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${order.number} • $service',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatRupiah(order.total),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                _StatusChip(status: order.status),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final OrderStatus status;

  Color get _color => switch (status) {
        OrderStatus.received => Colors.blueGrey,
        OrderStatus.washing => Colors.blue,
        OrderStatus.drying => Colors.orange,
        OrderStatus.ironing => Colors.deepPurple,
        OrderStatus.ready => Colors.green,
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