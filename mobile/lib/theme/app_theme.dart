import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  // Common Font Fallbacks for Commercial POS clarity
  static const List<String> _fontFamilyFallback = [
    'Plus Jakarta Sans',
    'Inter',
    'Roboto',
    'Segoe UI',
    'sans-serif',
  ];

  static ThemeData light() {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryContainerLight,
      onPrimaryContainer: AppColors.primaryDark,
      secondary: AppColors.indigo,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.indigoLight,
      onSecondaryContainer: AppColors.indigoDark,
      tertiary: AppColors.teal,
      onTertiary: Colors.white,
      tertiaryContainer: AppColors.tealLight,
      onTertiaryContainer: AppColors.tealDark,
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightTextPrimary,
      surfaceContainerLowest: AppColors.lightSurface,
      surfaceContainerLow: AppColors.lightBg,
      surfaceContainer: AppColors.lightSurfaceElevated,
      surfaceContainerHigh: Color(0xFFDCE5F2),
      surfaceContainerHighest: Color(0xFFCBD5E1),
      error: AppColors.danger,
      onError: Colors.white,
      errorContainer: AppColors.dangerLight,
      onErrorContainer: AppColors.dangerText,
      outline: AppColors.lightBorder,
      outlineVariant: Color(0xFFE2E8F0),
    );

    return _buildTheme(colorScheme, isDark: false);
  }

  static ThemeData dark() {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.primaryLight,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryContainerDark,
      onPrimaryContainer: Colors.white,
      secondary: AppColors.indigoGlow,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.darkSurfaceElevated,
      onSecondaryContainer: AppColors.darkTextPrimary,
      tertiary: AppColors.tealGlow,
      onTertiary: AppColors.darkBg,
      tertiaryContainer: AppColors.tealDark,
      onTertiaryContainer: AppColors.tealLight,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkTextPrimary,
      surfaceContainerLowest: AppColors.darkBg,
      surfaceContainerLow: Color(0xFF101829),
      surfaceContainer: AppColors.darkSurfaceElevated,
      surfaceContainerHigh: Color(0xFF283753),
      surfaceContainerHighest: Color(0xFF334463),
      error: AppColors.danger,
      onError: Colors.white,
      errorContainer: AppColors.dangerDark,
      onErrorContainer: Color(0xFFFCA5A5),
      outline: AppColors.darkBorder,
      outlineVariant: Color(0xFF334155),
    );

    return _buildTheme(colorScheme, isDark: true);
  }

  static ThemeData _buildTheme(ColorScheme cs, {required bool isDark}) {
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final baseTextTheme = Typography.material2021().black;
    final textTheme = baseTextTheme.copyWith(
      displayMedium: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: textPrimary,
        fontFamilyFallback: _fontFamilyFallback,
        letterSpacing: -0.6,
      ),
      headlineMedium: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: textPrimary,
        fontFamilyFallback: _fontFamilyFallback,
        letterSpacing: -0.4,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        fontFamilyFallback: _fontFamilyFallback,
        letterSpacing: -0.2,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        fontFamilyFallback: _fontFamilyFallback,
      ),
      bodyLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textPrimary,
        fontFamilyFallback: _fontFamilyFallback,
        height: 1.4,
      ),
      bodyMedium: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: textSecondary,
        fontFamilyFallback: _fontFamilyFallback,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: textSecondary,
        fontFamilyFallback: _fontFamilyFallback,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        fontFamilyFallback: _fontFamilyFallback,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: textSecondary,
        fontFamilyFallback: _fontFamilyFallback,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: textSecondary,
        fontFamilyFallback: _fontFamilyFallback,
        letterSpacing: 0.2,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: bgColor,
      textTheme: textTheme,
      fontFamilyFallback: _fontFamilyFallback,

      // AppBar Theme — Commercial POS Style
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          fontFamilyFallback: _fontFamilyFallback,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: Colors.white, size: 22),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: borderColor, width: 1.2),
        ),
      ),

      // Buttons
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          backgroundColor: isDark ? AppColors.primaryBright : AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            fontFamilyFallback: _fontFamilyFallback,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          foregroundColor: textPrimary,
          side: BorderSide(color: borderColor, width: 1.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            fontFamilyFallback: _fontFamilyFallback,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? AppColors.primaryLight : AppColors.primaryBright,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            fontFamilyFallback: _fontFamilyFallback,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),

      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? AppColors.primaryLight : AppColors.primaryBright,
            width: 2.0,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.2),
        ),
        hintStyle: TextStyle(
          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        labelStyle: TextStyle(
          color: textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),

      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        selectedColor: isDark
            ? AppColors.primaryBright.withValues(alpha: 0.3)
            : AppColors.primaryContainerLight,
        side: BorderSide(color: borderColor, width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          fontFamilyFallback: _fontFamilyFallback,
        ),
      ),

      // Navigation Bar
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        indicatorColor: isDark
            ? AppColors.primaryLight.withValues(alpha: 0.22)
            : AppColors.primaryContainerLight,
        elevation: 8,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected
                ? (isDark ? AppColors.primaryLight : AppColors.primary)
                : textSecondary,
            fontFamilyFallback: _fontFamilyFallback,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 22,
            color: isSelected
                ? (isDark ? AppColors.primaryLight : AppColors.primary)
                : textSecondary,
          );
        }),
      ),

      // Dividers
      dividerTheme: DividerThemeData(
        color: borderColor,
        thickness: 1,
        space: 1,
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: borderColor, width: 1.2),
        ),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: textPrimary,
          fontFamilyFallback: _fontFamilyFallback,
        ),
      ),

      // Bottom Sheet
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        modalBackgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        elevation: 12,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      // Floating Action Button
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryBright,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
