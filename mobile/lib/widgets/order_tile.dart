import 'package:flutter/material.dart';

import '../models/order.dart';
import '../models/order_option.dart';
import '../models/order_status.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';
import 'order_badges.dart';
import 'status_chip.dart';

/// Bespoke Die-Cut Perforated POS Ticket Stub Card
/// Features authentic semicircular side punch notches, a two-tone stub header
/// & footer, overflow-proof flex constraints, and tactile commercial hierarchy.
class OrderTile extends StatelessWidget {
  const OrderTile({super.key, required this.order, required this.onTap});

  final Order order;
  final VoidCallback onTap;

  Color _statusAccent(OrderStatus status) {
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
    final accent = _statusAccent(order.status);
    final isOverdue = order.isOverdue;
    final customerName =
        order.customer.name.isEmpty ? 'Pelanggan Umum' : order.customer.name;
    final avatarStyle = AppColors.avatarStyle(customerName, isDark: isDark);
    final borderColor = isOverdue
        ? AppColors.danger.withValues(alpha: isDark ? 0.8 : 0.6)
        : accent.withValues(alpha: isDark ? 0.45 : 0.28);

    final servicesSummary = order.lines.isEmpty
        ? 'Layanan Laundry Reguler'
        : order.lines
            .map((l) => '${formatQty(l.qty)} ${l.unit} ${l.serviceName}')
            .join(' • ');

    // Calculate fractional notch position (~69% down the ticket height)
    const notchFraction = 0.67;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6.5),
      child: CustomPaint(
        painter: _TicketStubBorderPainter(
          borderColor: borderColor,
          accentColor: accent,
          bgColor: isDark ? AppColors.darkSurface : Colors.white,
          stubBgColor: isDark
              ? accent.withValues(alpha: 0.10)
              : accent.withValues(alpha: 0.045),
          dividerColor: isDark
              ? accent.withValues(alpha: 0.35)
              : accent.withValues(alpha: 0.22),
          notchFraction: notchFraction,
          isDark: isDark,
        ),
        child: ClipPath(
          clipper: const _TicketStubClipper(notchFraction: notchFraction),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. TOP TICKET RIBBON HEADER (Tinted Banner + Diagonal Tag Feel)
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 9, 12, 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          accent.withValues(alpha: isDark ? 0.24 : 0.12),
                          accent.withValues(alpha: isDark ? 0.06 : 0.02),
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        // Left scrollable/flexible badges group (Overflow-proof)
                        Expanded(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              // Ticket Number Tag
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2.5,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.darkSurface
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: accent.withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.confirmation_number_rounded,
                                      size: 11.5,
                                      color: accent,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      order.number,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: isDark
                                            ? Colors.white
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
                                  order.priority == OrderPriority.express)
                                const PriorityBadge(label: 'Kilat'),

                              if (order.fulfillment == Fulfillment.delivery)
                                const FulfillmentBadge(
                                  fulfillment: Fulfillment.delivery,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        StatusChip(status: order.status),
                      ],
                    ),
                  ),

                  // 2. MAIN CUSTOMER & SERVICE BODY
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 14, 13),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Hex/Squircle Styled Avatar Container with Accent Ring
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: avatarStyle.bg,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(14),
                              topRight: Radius.circular(6),
                              bottomLeft: Radius.circular(6),
                              bottomRight: Radius.circular(14),
                            ),
                            border: Border.all(
                              color: avatarStyle.text.withValues(alpha: 0.3),
                              width: 1.2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              _initials(customerName),
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: avatarStyle.text,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Customer Name, Phone, & Service Pill (100% Overflow-Safe)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    flex: 3,
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
                                    Flexible(
                                      flex: 2,
                                      child: Text(
                                        '• ${order.customer.phone}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? AppColors.darkTextMuted
                                              : AppColors.lightTextMuted,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3.5,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.darkSurfaceElevated
                                      : AppColors.lightSurfaceElevated,
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.local_laundry_service_outlined,
                                      size: 12.5,
                                      color: accent,
                                    ),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        servicesSummary,
                                        style: TextStyle(
                                          fontSize: 11.5,
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
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 3. PERFORATED TEAR-OFF FINANCIAL STUB FOOTER
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
                    child: Row(
                      children: [
                        // Left: Price + Payment Status (Wrapped in Expanded so it never overflows)
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
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
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 7),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2.5,
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
                                      size: 11,
                                      color: payColor.icon,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      order.paymentLabel,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: payColor.text,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 6),

                        // Right: Due Label (constrained) + Tactile Action Button
                        Flexible(
                          flex: 0,
                          child: DueLabel(order: order),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: isDark ? 0.25 : 0.14),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: isDark ? Colors.white : accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom Clipper that creates a bespoke Ticket Stub shape:
/// - Asymmetric chamfered/rounded corners
/// - Left and right semicircular punch-out notches at [notchFraction]
class _TicketStubClipper extends CustomClipper<Path> {
  const _TicketStubClipper({required this.notchFraction});

  final double notchFraction;

  static Path buildTicketPath(Size size, double notchFraction) {
    const double cornerRadius = 18.0;
    const double notchRadius = 8.5;
    final double notchY = size.height * notchFraction;

    final path = Path();

    // Start top-left after corner
    path.moveTo(0, cornerRadius);
    path.quadraticBezierTo(0, 0, cornerRadius, 0);

    // Top edge to top-right corner
    path.lineTo(size.width - cornerRadius, 0);
    path.quadraticBezierTo(size.width, 0, size.width, cornerRadius);

    // Right edge down to right semicircular punch notch
    path.lineTo(size.width, notchY - notchRadius);
    path.arcToPoint(
      Offset(size.width, notchY + notchRadius),
      radius: const Radius.circular(notchRadius),
      clockwise: false,
    );

    // Right edge down to bottom-right corner
    path.lineTo(size.width, size.height - cornerRadius);
    path.quadraticBezierTo(
      size.width,
      size.height,
      size.width - cornerRadius,
      size.height,
    );

    // Bottom edge to bottom-left corner
    path.lineTo(cornerRadius, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height - cornerRadius);

    // Left edge up to left semicircular punch notch
    path.lineTo(0, notchY + notchRadius);
    path.arcToPoint(
      Offset(0, notchY - notchRadius),
      radius: const Radius.circular(notchRadius),
      clockwise: false,
    );

    path.close();
    return path;
  }

  @override
  Path getClip(Size size) => buildTicketPath(size, notchFraction);

  @override
  bool shouldReclip(covariant _TicketStubClipper oldClipper) =>
      oldClipper.notchFraction != notchFraction;
}

/// Custom Painter that draws:
/// 1. Soft ambient shadow following the die-cut ticket silhouette
/// 2. Main ticket surface & tinted lower tear-off stub surface
/// 3. Left semantic accent stripe above the punch notch
/// 4. Perforated dashed tear line connecting left and right punch notches
/// 5. Crisp border following the semicircular notches
class _TicketStubBorderPainter extends CustomPainter {
  const _TicketStubBorderPainter({
    required this.borderColor,
    required this.accentColor,
    required this.bgColor,
    required this.stubBgColor,
    required this.dividerColor,
    required this.notchFraction,
    required this.isDark,
  });

  final Color borderColor;
  final Color accentColor;
  final Color bgColor;
  final Color stubBgColor;
  final Color dividerColor;
  final double notchFraction;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final ticketPath = _TicketStubClipper.buildTicketPath(size, notchFraction);
    final notchY = size.height * notchFraction;
    const notchRadius = 8.5;

    // 1. Draw subtle shadow
    canvas.drawShadow(
      ticketPath,
      isDark
          ? Colors.black.withValues(alpha: 0.6)
          : const Color(0xFF1E40AF).withValues(alpha: 0.14),
      6,
      false,
    );

    // 2. Fill main ticket background
    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(ticketPath, bgPaint);

    // 3. Fill bottom stub section with subtle tint
    canvas.save();
    canvas.clipPath(ticketPath);
    final stubRect = Rect.fromLTWH(0, notchY, size.width, size.height - notchY);
    canvas.drawRect(stubRect, Paint()..color = stubBgColor);

    // 4. Draw left vertical semantic bar (from top down to the notch)
    final barRect = Rect.fromLTWH(0, 0, 5.5, notchY - notchRadius);
    canvas.drawRect(barRect, Paint()..color = accentColor);
    canvas.restore();

    // 5. Draw perforated dashed line between the two semicircular notches
    final dashPaint = Paint()
      ..color = dividerColor
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;

    const dashWidth = 5.0;
    const dashSpace = 4.0;
    double startX = notchRadius + 6;
    final endX = size.width - notchRadius - 6;
    while (startX < endX) {
      canvas.drawLine(
        Offset(startX, notchY),
        Offset((startX + dashWidth).clamp(0.0, endX), notchY),
        dashPaint,
      );
      startX += dashWidth + dashSpace;
    }

    // 6. Draw crisp outline around the entire notched ticket path
    final borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;
    canvas.drawPath(ticketPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _TicketStubBorderPainter oldDelegate) =>
      oldDelegate.borderColor != borderColor ||
      oldDelegate.accentColor != accentColor ||
      oldDelegate.bgColor != bgColor ||
      oldDelegate.isDark != isDark;
}
