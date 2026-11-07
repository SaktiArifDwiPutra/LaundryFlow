import 'package:flutter/material.dart';

import '../models/order_status.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final (Color bg, Color text, IconData icon) = switch (status) {
      OrderStatus.received => (
          isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
          Icons.inventory_2_outlined,
        ),
      OrderStatus.washing => (
          isDark ? const Color(0xFF172554) : const Color(0xFFDBEAFE),
          isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
          Icons.local_laundry_service_outlined,
        ),
      OrderStatus.drying => (
          isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7),
          isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309),
          Icons.dry_cleaning_outlined,
        ),
      OrderStatus.ironing => (
          isDark ? const Color(0xFF3B0764) : const Color(0xFFF3E8FF),
          isDark ? const Color(0xFFD8B4FE) : const Color(0xFF7E22CE),
          Icons.iron_outlined,
        ),
      OrderStatus.ready => (
          isDark ? const Color(0xFF052E16) : const Color(0xFFDCFCE7),
          isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D),
          Icons.check_circle_outline,
        ),
      OrderStatus.outForDelivery => (
          isDark ? const Color(0xFF134E4A) : const Color(0xFFCCFBF1),
          isDark ? const Color(0xFF5EEAD4) : const Color(0xFF0F766E),
          Icons.delivery_dining_outlined,
        ),
      OrderStatus.completed => (
          isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          isDark ? const Color(0xFF64748B) : const Color(0xFF475569),
          Icons.done_all,
        ),
      OrderStatus.unknown => (
          isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2),
          isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
          Icons.help_outline,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: text),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              color: text,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
