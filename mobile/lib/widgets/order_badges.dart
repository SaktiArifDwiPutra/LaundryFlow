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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        gradient: isDark ? null : AppColors.expressGradient,
        color: isDark ? AppColors.warmOrangeDark.withValues(alpha: 0.65) : null,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: isDark
              ? AppColors.warmOrangeGlow.withValues(alpha: 0.45)
              : AppColors.warmOrange,
          width: 1,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: AppColors.warmOrange.withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bolt_rounded,
            size: 13,
            color: isDark ? AppColors.warmOrangeGlow : Colors.white,
          ),
          const SizedBox(width: 2.5),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: isDark ? AppColors.warmOrangeGlow : Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final delivery = fulfillment == Fulfillment.delivery;
    final bg = delivery
        ? (isDark ? AppColors.cyanDark.withValues(alpha: 0.55) : AppColors.cyanLight)
        : (isDark ? AppColors.darkSurfaceElevated : AppColors.neutralLight);
    final fg = delivery
        ? (isDark ? AppColors.cyanGlow : AppColors.cyan)
        : (isDark ? AppColors.darkTextSecondary : AppColors.neutralDark);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: delivery
              ? fg.withValues(alpha: 0.3)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            delivery ? Icons.delivery_dining_rounded : Icons.storefront_rounded,
            size: 13.5,
            color: fg,
          ),
          const SizedBox(width: 4),
          Text(
            fulfillment.label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overdue = order.isOverdue;

    if (overdue) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: isDark ? AppColors.dangerDark.withValues(alpha: 0.6) : AppColors.dangerLight,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.alarm_on_rounded,
              size: 12,
              color: isDark ? const Color(0xFFFDA4AF) : AppColors.dangerText,
            ),
            const SizedBox(width: 3.5),
            Flexible(
              child: Text(
                'Terlambat ${formatOverdue(due)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  color: isDark ? const Color(0xFFFDA4AF) : AppColors.dangerText,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.schedule_rounded,
          size: 12.5,
          color: isDark ? AppColors.darkTextSecondary : AppColors.neutral,
        ),
        const SizedBox(width: 3.5),
        Flexible(
          child: Text(
            'Tenggat ${formatDue(due)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? AppColors.darkTextSecondary : AppColors.neutral,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
