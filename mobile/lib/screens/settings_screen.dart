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
    // ValueListenableBuilder in main.dart handles the navigation to LoginScreen,
    // but we also pop any stacked routes to avoid a stale navigator state.
    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final user = currentUser.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Setelan & Akun'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Staff Account Profile Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        (user?.name.isNotEmpty == true)
                            ? user!.name.substring(0, 1).toUpperCase()
                            : 'K',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'Staf Kasir',
                          style: textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.username ?? 'kasir@laundryflow',
                          style: textTheme.bodySmall,
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.successLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Sesi Aktif',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.successText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Theme Settings Section
          Text('Tampilan & Tema', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          ListenableBuilder(
            listenable: themeController,
            builder: (context, _) {
              final currentMode = themeController.themeMode;
              return Card(
                child: RadioGroup<ThemeMode>(
                  groupValue: currentMode,
                  onChanged: (mode) {
                    if (mode != null) themeController.setThemeMode(mode);
                  },
                  child: Column(
                    children: [
                      RadioListTile<ThemeMode>(
                        value: ThemeMode.system,
                        title: const Text('Ikuti Sistem (Default)'),
                        subtitle: const Text('Otomatis berganti terang/gelap'),
                        secondary: const Icon(Icons.brightness_auto),
                      ),
                      const Divider(height: 1),
                      RadioListTile<ThemeMode>(
                        value: ThemeMode.light,
                        title: const Text('Mode Terang (Light)'),
                        subtitle: const Text('Tampilan bersih dan kontras tinggi'),
                        secondary: const Icon(Icons.light_mode),
                      ),
                      const Divider(height: 1),
                      RadioListTile<ThemeMode>(
                        value: ThemeMode.dark,
                        title: const Text('Mode Gelap (Dark)'),
                        subtitle: const Text('Nyaman untuk operasional malam'),
                        secondary: const Icon(Icons.dark_mode),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // App & Connection Info
          Text('Informasi Aplikasi', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Versi Aplikasi'),
                  trailing: Text('1.0.0 (Build 1)', style: textTheme.bodyMedium),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.dns_outlined),
                  title: const Text('Server Odoo'),
                  subtitle: Text(baseUrl, style: textTheme.bodySmall),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: useMock
                          ? AppColors.warningLight
                          : AppColors.primaryContainerLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      useMock ? 'MOCK' : 'API RIIL',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: useMock ? AppColors.warningText : AppColors.primaryDark,
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('Design System'),
                  trailing: Text('M3 + Stitch POS', style: textTheme.bodyMedium),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Sign Out Action Button
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger, width: 1.2),
            ),
            icon: const Icon(Icons.logout, size: 20),
            label: const Text('Keluar dari Akun Kasir'),
            onPressed: () => _logout(context),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

