import 'package:flutter/material.dart';
import '../models/order_status.dart';

/// Centralized Design Tokens for LaundryFlow Commercial POS 2.0
/// ("Tactile Commercial POS" — Royal Blue, Indigo, Cyan, Violet, Teal, Warm Orange)
class AppColors {
  // 1. Primary Brand Colors — Royal Blue & Rich Indigo
  static const Color primary = Color(0xFF1E40AF); // Deep Royal Blue
  static const Color primaryBright = Color(0xFF2563EB); // Electric Cobalt
  static const Color primaryDark = Color(0xFF1E3A8A); // Navy Cobalt
  static const Color primaryLight = Color(0xFF3B82F6); // Luminous Blue (Dark Mode)
  static const Color primaryContainerLight = Color(0xFFDBEAFE); // Tinted Royal Blue 100
  static const Color primaryContainerDark = Color(0xFF1E3A8A); // Deep Royal Container

  // 2. Multi-Hue Commercial POS Palette
  static const Color indigo = Color(0xFF4338CA); // Rich Indigo 700
  static const Color indigoDark = Color(0xFF312E81); // Deep Indigo 900
  static const Color indigoLight = Color(0xFFE0E7FF); // Indigo 100
  static const Color indigoGlow = Color(0xFF818CF8); // Indigo 400 (Dark Mode)

  static const Color cyan = Color(0xFF0891B2); // Vivid Cyan 600
  static const Color cyanBright = Color(0xFF06B6D4); // Cyan 500
  static const Color cyanLight = Color(0xFFCFFAFE); // Cyan 100
  static const Color cyanDark = Color(0xFF164E63); // Cyan 900
  static const Color cyanGlow = Color(0xFF22D3EE); // Cyan 400 (Dark Mode)

  static const Color violet = Color(0xFF7C3AED); // Royal Violet 600
  static const Color violetDark = Color(0xFF4C1D95); // Violet 900
  static const Color violetLight = Color(0xFFEDE9FE); // Violet 100
  static const Color violetGlow = Color(0xFFA78BFA); // Violet 400 (Dark Mode)

  static const Color teal = Color(0xFF0D9488); // Commercial Teal 600
  static const Color tealDark = Color(0xFF134E4A); // Teal 900
  static const Color tealLight = Color(0xFFCCFBF1); // Teal 100
  static const Color tealGlow = Color(0xFF2DD4BF); // Teal 400 (Dark Mode)

  static const Color warmOrange = Color(0xFFEA580C); // Express Warm Orange 600
  static const Color warmOrangeBright = Color(0xFFF97316); // Warm Orange 500
  static const Color warmOrangeLight = Color(0xFFFFEDD5); // Orange 100
  static const Color warmOrangeDark = Color(0xFF7C2D12); // Orange 900
  static const Color warmOrangeGlow = Color(0xFFFB923C); // Orange 400 (Dark Mode)

  // 3. Semantic Status Colors
  static const Color success = Color(0xFF059669); // Emerald 600
  static const Color successLight = Color(0xFFD1FAE5); // Emerald 100
  static const Color successDark = Color(0xFF064E3B); // Emerald 900
  static const Color successText = Color(0xFF047857); // Emerald 700

  static const Color warning = Color(0xFFD97706); // Amber 600
  static const Color warningLight = Color(0xFFFEF3C7); // Amber 100
  static const Color warningDark = Color(0xFF78350F); // Amber 900
  static const Color warningText = Color(0xFFB45309); // Amber 700

  static const Color danger = Color(0xFFE11D48); // Crimson Rose 600
  static const Color dangerLight = Color(0xFFFFE4E6); // Rose 100
  static const Color dangerDark = Color(0xFF881337); // Rose 900
  static const Color dangerText = Color(0xFFBE123C); // Rose 700

  static const Color neutral = Color(0xFF64748B); // Slate 500
  static const Color neutralLight = Color(0xFFF1F5F9); // Slate 100
  static const Color neutralDark = Color(0xFF334155); // Slate 700

  // 4. Light Theme Surfaces & Text (Cool Porcelain Tinted Canvas)
  static const Color lightBg = Color(0xFFF3F6FC); // Cool Blue-Tinted Porcelain Canvas
  static const Color lightSurface = Color(0xFFFFFFFF); // Crisp Elevated Card
  static const Color lightSurfaceElevated = Color(0xFFEBF1FA); // Tinted Container Surface
  static const Color lightTextPrimary = Color(0xFF0F172A); // Deep Slate 900
  static const Color lightTextSecondary = Color(0xFF475569); // Slate 600
  static const Color lightTextMuted = Color(0xFF94A3B8); // Slate 400
  static const Color lightBorder = Color(0xFFDCE5F2); // Tinted Hairline Border

  // 5. Dark Theme Surfaces & Text (Intentional Midnight Indigo Command Deck)
  static const Color darkBg = Color(0xFF0B1120); // Midnight Obsidian Blue Canvas
  static const Color darkSurface = Color(0xFF131C31); // Rich Navy Card Surface
  static const Color darkSurfaceElevated = Color(0xFF1D2942); // Elevated Indigo-Slate Surface
  static const Color darkTextPrimary = Color(0xFFF8FAFC); // Crisp Alabaster
  static const Color darkTextSecondary = Color(0xFF94A3B8); // Cool Slate 400
  static const Color darkTextMuted = Color(0xFF64748B); // Slate 500
  static const Color darkBorder = Color(0xFF26354D); // Luminous Navy Rim Border

  // 6. Signature Commercial POS Gradients
  static LinearGradient heroGradient({bool isDark = false}) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? const [
                Color(0xFF1E1B4B), // Deep Indigo 950
                Color(0xFF1E3A8A), // Royal Navy 900
                Color(0xFF0F172A), // Midnight Slate
              ]
            : const [
                Color(0xFF1E40AF), // Royal Blue 800
                Color(0xFF3730A3), // Rich Indigo 800
                Color(0xFF1D4ED8), // Cobalt 700
              ],
      );

  static const LinearGradient primaryActionGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF2563EB),
      Color(0xFF4338CA),
    ],
  );

  static const LinearGradient expressGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF97316),
      Color(0xFFEA580C),
    ],
  );

  static const LinearGradient tealGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0D9488),
      Color(0xFF059669),
    ],
  );

  static const LinearGradient violetGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF7C3AED),
      Color(0xFF4338CA),
    ],
  );

  // 7. Ambient Tinted Shadows
  static List<BoxShadow> cardShadow({bool isDark = false}) => [
        BoxShadow(
          color: isDark
              ? const Color(0x55000000)
              : const Color(0xFF1E40AF).withValues(alpha: 0.06),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
        BoxShadow(
          color: isDark
              ? const Color(0x33000000)
              : const Color(0xFF0F172A).withValues(alpha: 0.03),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> glowShadow(Color color, {bool isDark = false}) => [
        BoxShadow(
          color: color.withValues(alpha: isDark ? 0.35 : 0.25),
          blurRadius: 14,
          offset: const Offset(0, 5),
        ),
      ];

  // 8. Semantic Stage Palette (Distinct multi-hue per operational stage)
  static StatusColor stageStyle(OrderStatus status, {bool isDark = false}) {
    switch (status) {
      case OrderStatus.received:
        return StatusColor(
          bg: isDark ? indigoDark.withValues(alpha: 0.55) : indigoLight,
          text: isDark ? indigoGlow : indigo,
          icon: isDark ? indigoGlow : indigo,
          border: isDark ? indigoGlow.withValues(alpha: 0.4) : indigo.withValues(alpha: 0.25),
        );
      case OrderStatus.washing:
        return StatusColor(
          bg: isDark ? primaryContainerDark.withValues(alpha: 0.55) : primaryContainerLight,
          text: isDark ? const Color(0xFF93C5FD) : primary,
          icon: isDark ? primaryLight : primaryBright,
          border: isDark ? primaryLight.withValues(alpha: 0.4) : primaryBright.withValues(alpha: 0.25),
        );
      case OrderStatus.drying:
        return StatusColor(
          bg: isDark ? cyanDark.withValues(alpha: 0.6) : cyanLight,
          text: isDark ? cyanGlow : cyan,
          icon: isDark ? cyanGlow : cyanBright,
          border: isDark ? cyanGlow.withValues(alpha: 0.4) : cyan.withValues(alpha: 0.25),
        );
      case OrderStatus.ironing:
        return StatusColor(
          bg: isDark ? violetDark.withValues(alpha: 0.55) : violetLight,
          text: isDark ? violetGlow : violet,
          icon: isDark ? violetGlow : violet,
          border: isDark ? violetGlow.withValues(alpha: 0.4) : violet.withValues(alpha: 0.25),
        );
      case OrderStatus.ready:
        return StatusColor(
          bg: isDark ? tealDark.withValues(alpha: 0.6) : tealLight,
          text: isDark ? tealGlow : teal,
          icon: isDark ? tealGlow : teal,
          border: isDark ? tealGlow.withValues(alpha: 0.4) : teal.withValues(alpha: 0.3),
        );
      case OrderStatus.outForDelivery:
        return StatusColor(
          bg: isDark ? warmOrangeDark.withValues(alpha: 0.55) : warmOrangeLight,
          text: isDark ? warmOrangeGlow : warmOrange,
          icon: isDark ? warmOrangeGlow : warmOrangeBright,
          border: isDark ? warmOrangeGlow.withValues(alpha: 0.4) : warmOrange.withValues(alpha: 0.3),
        );
      case OrderStatus.completed:
        return StatusColor(
          bg: isDark ? successDark.withValues(alpha: 0.5) : successLight,
          text: isDark ? const Color(0xFF6EE7B7) : successText,
          icon: isDark ? const Color(0xFF6EE7B7) : success,
          border: isDark ? const Color(0xFF6EE7B7).withValues(alpha: 0.35) : success.withValues(alpha: 0.25),
        );
      case OrderStatus.unknown:
        return StatusColor(
          bg: isDark ? dangerDark.withValues(alpha: 0.5) : dangerLight,
          text: isDark ? const Color(0xFFFDA4AF) : dangerText,
          icon: isDark ? const Color(0xFFFDA4AF) : danger,
          border: isDark ? danger.withValues(alpha: 0.4) : danger.withValues(alpha: 0.25),
        );
    }
  }

  // 9. Helper method for payment status coloring
  static StatusColor paymentStatus(String status, {bool isDark = false}) {
    switch (status.toLowerCase()) {
      case 'paid':
        return StatusColor(
          bg: isDark ? successDark.withValues(alpha: 0.55) : successLight,
          text: isDark ? const Color(0xFF6EE7B7) : successText,
          icon: isDark ? const Color(0xFF34D399) : success,
          border: isDark ? const Color(0xFF34D399).withValues(alpha: 0.35) : success.withValues(alpha: 0.25),
        );
      case 'partial':
        return StatusColor(
          bg: isDark ? warmOrangeDark.withValues(alpha: 0.55) : warmOrangeLight,
          text: isDark ? warmOrangeGlow : warmOrange,
          icon: isDark ? warmOrangeGlow : warmOrangeBright,
          border: isDark ? warmOrangeGlow.withValues(alpha: 0.35) : warmOrange.withValues(alpha: 0.25),
        );
      case 'unpaid':
      default:
        return StatusColor(
          bg: isDark ? dangerDark.withValues(alpha: 0.55) : dangerLight,
          text: isDark ? const Color(0xFFFDA4AF) : dangerText,
          icon: isDark ? const Color(0xFFFB7185) : danger,
          border: isDark ? const Color(0xFFFB7185).withValues(alpha: 0.35) : danger.withValues(alpha: 0.25),
        );
    }
  }

  // 10. Deterministic vibrant avatar color based on customer name
  static StatusColor avatarStyle(String name, {bool isDark = false}) {
    final palettes = <StatusColor>[
      StatusColor(
        bg: isDark ? primaryContainerDark : primaryContainerLight,
        text: isDark ? const Color(0xFF93C5FD) : primary,
        icon: primaryBright,
      ),
      StatusColor(
        bg: isDark ? indigoDark : indigoLight,
        text: isDark ? indigoGlow : indigo,
        icon: indigo,
      ),
      StatusColor(
        bg: isDark ? tealDark : tealLight,
        text: isDark ? tealGlow : teal,
        icon: teal,
      ),
      StatusColor(
        bg: isDark ? violetDark : violetLight,
        text: isDark ? violetGlow : violet,
        icon: violet,
      ),
      StatusColor(
        bg: isDark ? cyanDark : cyanLight,
        text: isDark ? cyanGlow : cyan,
        icon: cyanBright,
      ),
      StatusColor(
        bg: isDark ? warmOrangeDark : warmOrangeLight,
        text: isDark ? warmOrangeGlow : warmOrange,
        icon: warmOrangeBright,
      ),
    ];
    if (name.isEmpty) return palettes[0];
    final hash = name.codeUnits.fold<int>(0, (prev, elem) => prev + elem);
    return palettes[hash % palettes.length];
  }
}

class StatusColor {
  const StatusColor({
    required this.bg,
    required this.text,
    required this.icon,
    this.border = Colors.transparent,
  });

  final Color bg;
  final Color text;
  final Color icon;
  final Color border;
}
