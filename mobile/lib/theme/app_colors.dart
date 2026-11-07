import 'package:flutter/material.dart';

/// Centralized Design Tokens for LaundryFlow Modern SaaS POS
class AppColors {
  // Brand Colors - Electric Cobalt & Indigo
  static const Color primary = Color(0xFF2563EB); // Modern Royal Blue
  static const Color primaryDark = Color(0xFF1D4ED8); // Deep Cobalt
  static const Color primaryLight = Color(0xFF3B82F6); // Electric Blue
  static const Color primaryContainerLight = Color(0xFFEFF6FF); // Soft Blue 50
  static const Color primaryContainerDark = Color(0xFF1E293B); // Slate Blue 800

  // Semantic Colors - Modern SaaS Palette
  static const Color success = Color(0xFF059669); // Emerald 600
  static const Color successLight = Color(0xFFECFDF5); // Emerald 50
  static const Color successDark = Color(0xFF064E3B); // Emerald 900
  static const Color successText = Color(0xFF047857); // Emerald 700

  static const Color warning = Color(0xFFD97706); // Amber 600
  static const Color warningLight = Color(0xFFFFFBEB); // Amber 50
  static const Color warningDark = Color(0xFF78350F); // Amber 900
  static const Color warningText = Color(0xFFB45309); // Amber 700

  static const Color danger = Color(0xFFE11D48); // Rose 600
  static const Color dangerLight = Color(0xFFFFF1F2); // Rose 50
  static const Color dangerDark = Color(0xFF881337); // Rose 900
  static const Color dangerText = Color(0xFFBE123C); // Rose 700

  static const Color neutral = Color(0xFF64748B); // Slate 500
  static const Color neutralLight = Color(0xFFF1F5F9); // Slate 100
  static const Color neutralDark = Color(0xFF334155); // Slate 700

  // Light Theme Surfaces & Text (Crisp Modern SaaS)
  static const Color lightBg = Color(0xFFF8FAFC); // Clean Slate Canvas
  static const Color lightSurface = Color(0xFFFFFFFF); // Pure White Card
  static const Color lightSurfaceElevated = Color(0xFFF1F5F9); // Subtle Container
  static const Color lightTextPrimary = Color(0xFF0F172A); // Slate 900
  static const Color lightTextSecondary = Color(0xFF475569); // Slate 600
  static const Color lightTextMuted = Color(0xFF94A3B8); // Slate 400
  static const Color lightBorder = Color(0xFFE2E8F0); // 1px Hairline Border

  // Dark Theme Surfaces & Text (Quiet Luxury Modern Dark)
  static const Color darkBg = Color(0xFF090D16); // Deep Navy Canvas
  static const Color darkSurface = Color(0xFF111827); // Surface Slate 900
  static const Color darkSurfaceElevated = Color(0xFF1F2937); // Card Slate 800
  static const Color darkTextPrimary = Color(0xFFF8FAFC); // Crisp Slate 50
  static const Color darkTextSecondary = Color(0xFF94A3B8); // Slate 400
  static const Color darkTextMuted = Color(0xFF64748B); // Slate 500
  static const Color darkBorder = Color(0xFF1E293B); // Subtle Dark Hairline

  // Modern SaaS Shadows
  static List<BoxShadow> cardShadow({bool isDark = false}) => [
        BoxShadow(
          color: isDark ? const Color(0x33000000) : const Color(0x08000000),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
        BoxShadow(
          color: isDark ? const Color(0x22000000) : const Color(0x05000000),
          blurRadius: 3,
          offset: const Offset(0, 1),
        ),
      ];

  // Helper method for payment status coloring
  static StatusColor paymentStatus(String status, {bool isDark = false}) {
    switch (status.toLowerCase()) {
      case 'paid':
        return StatusColor(
          bg: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.4) : successLight,
          text: isDark ? const Color(0xFF6EE7B7) : successText,
          icon: isDark ? const Color(0xFF6EE7B7) : success,
        );
      case 'partial':
        return StatusColor(
          bg: isDark ? const Color(0xFF78350F).withValues(alpha: 0.4) : warningLight,
          text: isDark ? const Color(0xFFFCD34D) : warningText,
          icon: isDark ? const Color(0xFFFCD34D) : warning,
        );
      case 'unpaid':
      default:
        return StatusColor(
          bg: isDark ? const Color(0xFF881337).withValues(alpha: 0.4) : dangerLight,
          text: isDark ? const Color(0xFFFDA4AF) : dangerText,
          icon: isDark ? const Color(0xFFFDA4AF) : danger,
        );
    }
  }
}

class StatusColor {
  const StatusColor({
    required this.bg,
    required this.text,
    required this.icon,
  });

  final Color bg;
  final Color text;
  final Color icon;
}

