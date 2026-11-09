import 'package:flutter/material.dart';

import '../config.dart';
import '../repositories/repositories.dart';
import '../session.dart';
import '../theme/app_colors.dart';
import '../theme/theme_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Keluar'),
        content: const Text(
          'Apakah Anda yakin ingin keluar dari sesi kasir LaundryFlow?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Ya, Keluar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await authRepository.logout();
    } finally {
      await clearSession();
    }
    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;
    final user = currentUser.value;

    return Scaffold(
      body: Column(
        children: [
          // 1. Commercial Hero Profile Header
          Container(
            padding: EdgeInsets.fromLTRB(16, topPadding + 12, 16, 18),
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient(isDark: isDark),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: (isDark ? Colors.black : AppColors.primary)
                      .withValues(alpha: isDark ? 0.45 : 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Setelan & Terminal Kasir',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.24),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            (user?.name.isNotEmpty == true)
                                ? user!.name.substring(0, 1).toUpperCase()
                                : 'K',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.name ?? 'Staf Kasir',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user?.username ?? 'kasir@laundryflow',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFFDBEAFE),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.teal,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'AKTIF',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
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

          // 2. Settings Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
              children: [
                // Adaptive Theme Selection Cards
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: AppColors.violet.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.palette_rounded,
                        size: 15,
                        color: AppColors.violet,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Tampilan & Tema Adaptif',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ListenableBuilder(
                  listenable: themeController,
                  builder: (context, _) {
                    final currentMode = themeController.themeMode;
                    return Row(
                      children: [
                        Expanded(
                          child: _ThemeOptionCard(
                            label: 'Sistem',
                            subtitle: 'Otomatis',
                            icon: Icons.brightness_auto_rounded,
                            accent: AppColors.indigo,
                            selected: currentMode == ThemeMode.system,
                            isDark: isDark,
                            onTap: () => themeController
                                .setThemeMode(ThemeMode.system),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ThemeOptionCard(
                            label: 'Terang',
                            subtitle: 'Porcelain',
                            icon: Icons.light_mode_rounded,
                            accent: AppColors.warmOrangeBright,
                            selected: currentMode == ThemeMode.light,
                            isDark: isDark,
                            onTap: () => themeController
                                .setThemeMode(ThemeMode.light),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ThemeOptionCard(
                            label: 'Gelap',
                            subtitle: 'Midnight',
                            icon: Icons.dark_mode_rounded,
                            accent: AppColors.cyanBright,
                            selected: currentMode == ThemeMode.dark,
                            isDark: isDark,
                            onTap: () =>
                                themeController.setThemeMode(ThemeMode.dark),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Server & System Info Card
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: AppColors.cyan.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.dns_rounded,
                        size: 15,
                        color: AppColors.cyan,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Koneksi Server & Aplikasi',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color:
                          isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      width: 1.2,
                    ),
                    boxShadow: AppColors.cardShadow(isDark: isDark),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color:
                                AppColors.primaryBright.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.cloud_done_rounded,
                            color: AppColors.primaryBright,
                            size: 18,
                          ),
                        ),
                        title: const Text(
                          'Server Odoo 20',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(baseUrl, style: textTheme.bodySmall),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: useMock
                                ? AppColors.warmOrangeLight
                                : AppColors.tealLight,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            useMock ? 'MOCK' : 'LIVE API',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color:
                                  useMock ? AppColors.warmOrange : AppColors.teal,
                            ),
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.indigo.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.layers_rounded,
                            color: AppColors.indigo,
                            size: 18,
                          ),
                        ),
                        title: const Text(
                          'Sistem Desain POS',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        trailing: Text(
                          'Commercial POS 2.0',
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.teal.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.verified_user_rounded,
                            color: AppColors.teal,
                            size: 18,
                          ),
                        ),
                        title: const Text(
                          'Versi Rilis',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        trailing: Text(
                          'v2.0.0 (Build 2)',
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Sign Out Button
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger, width: 1.5),
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  label: const Text(
                    'Keluar dari Sesi Kasir',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  onPressed: () => _logout(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeOptionCard extends StatelessWidget {
  const _ThemeOptionCard({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: isDark ? 0.22 : 0.10)
                : (isDark ? AppColors.darkSurface : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? accent
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: selected ? 2.0 : 1.2,
            ),
            boxShadow: AppColors.cardShadow(isDark: isDark),
          ),
          child: Column(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: selected
                      ? accent
                      : accent.withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: selected ? Colors.white : accent,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.lightTextPrimary,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10.5,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
