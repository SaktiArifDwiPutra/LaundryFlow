import 'package:flutter/material.dart';

/// Centralized Design Tokens for LaundryFlow POS
class AppColors {
  // Brand Colors
  static const Color primary = Color(0xFF2563EB); // Tailwind Blue 600
  static const Color primaryDark = Color(0xFF1D4ED8); // Tailwind Blue 700
  static const Color primaryLight = Color(0xFF3B82F6); // Blue 500
  static const Color primaryContainerLight = Color(0xFFDBEAFE); // Blue 100
  static const Color primaryContainerDark = Color(0xFF1E3A8A); // Blue 900

  // Semantic Colors
  static const Color success = Color(0xFF16A34A); // Green 600
  static const Color successLight = Color(0xFFDCFCE7); // Green 100
  static const Color successDark = Color(0xFF14532D); // Green 900
  static const Color successText = Color(0xFF15803D); // Green 700

  static const Color warning = Color(0xFFD97706); // Amber 600
  static const Color warningLight = Color(0xFFFEF3C7); // Amber 100
  static const Color warningDark = Color(0xFF78350F); // Amber 900
  static const Color warningText = Color(0xFFB45309); // Amber 700

  static const Color danger = Color(0xFFDC2626); // Red 600
  static const Color dangerLight = Color(0xFFFEE2E2); // Red 100
  static const Color dangerDark = Color(0xFF7F1D1D); // Red 900
  static const Color dangerText = Color(0xFFB91C1C); // Red 700

  static const Color neutral = Color(0xFF64748B); // Slate 500
  static const Color neutralLight = Color(0xFFF1F5F9); // Slate 100
  static const Color neutralDark = Color(0xFF334155); // Slate 700

  // Light Theme Surfaces & Text
  static const Color lightBg = Color(0xFFF8FAFC); // Slate 50
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFF1F5F9); // Slate 100
  static const Color lightTextPrimary = Color(0xFF0F172A); // Slate 900
  static const Color lightTextSecondary = Color(0xFF64748B); // Slate 500
  static const Color lightTextMuted = Color(0xFF94A3B8); // Slate 400
  static const Color lightBorder = Color(0xFFE2E8F0); // Slate 200

  // Dark Theme Surfaces & Text
  static const Color darkBg = Color(0xFF0F172A); // Slate 900
  static const Color darkSurface = Color(0xFF1E293B); // Slate 800
  static const Color darkSurfaceElevated = Color(0xFF334155); // Slate 700
  static const Color darkTextPrimary = Color(0xFFF8FAFC); // Slate 50
  static const Color darkTextSecondary = Color(0xFF94A3B8); // Slate 400
  static const Color darkTextMuted = Color(0xFF64748B); // Slate 500
  static const Color darkBorder = Color(0xFF334155); // Slate 700

  // Helper method for payment status coloring
  static StatusColor paymentStatus(String status, {bool isDark = false}) {
    switch (status.toLowerCase()) {
      case 'paid':
        return StatusColor(
          bg: isDark ? successDark.withValues(alpha: 0.35) : successLight,
          text: isDark ? const Color(0xFF86EFAC) : successText,
          icon: isDark ? const Color(0xFF86EFAC) : success,
        );
      case 'partial':
        return StatusColor(
          bg: isDark ? warningDark.withValues(alpha: 0.35) : warningLight,
          text: isDark ? const Color(0xFFFDE68A) : warningText,
          icon: isDark ? const Color(0xFFFDE68A) : warning,
        );
      case 'unpaid':
      default:
        return StatusColor(
          bg: isDark ? dangerDark.withValues(alpha: 0.35) : dangerLight,
          text: isDark ? const Color(0xFFFCA5A5) : dangerText,
          icon: isDark ? const Color(0xFFFCA5A5) : danger,
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
