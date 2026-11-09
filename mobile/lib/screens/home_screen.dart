import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'customer_list_screen.dart';
import 'new_order_screen.dart';
import 'order_list_screen.dart';
import 'queue_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  // We maintain distinct GlobalKeys to allow refreshing child screens when a new order is placed
  final GlobalKey<State<QueueScreen>> _queueKey = GlobalKey();
  final GlobalKey<State<OrderListScreen>> _orderListKey = GlobalKey();

  void _switchToTab(int tabIndex) {
    if (tabIndex == 2) {
      _openNewOrder();
      return;
    }
    setState(() => _index = tabIndex);
  }

  Widget _buildBody() {
    switch (_index) {
      case 0:
        return QueueScreen(
          key: _queueKey,
          onNavigateTab: _switchToTab,
        );
      case 1:
        return OrderListScreen(key: _orderListKey);
      case 3:
        return const CustomerListScreen();
      case 4:
        return const SettingsScreen();
      default:
        return QueueScreen(
          key: _queueKey,
          onNavigateTab: _switchToTab,
        );
    }
  }

  Future<void> _openNewOrder() async {
    final created = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NewOrderScreen()),
    );
    if (created != null && mounted) {
      setState(() {
        _index = 0; // Return to dashboard/queue
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: _buildBody(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1.2,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? const Color(0x44000000) : const Color(0x0D1E40AF),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _switchToTab,
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: 'Beranda',
            ),
            const NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded),
              label: 'Pesanan',
            ),
            NavigationDestination(
              icon: Container(
                width: 46,
                height: 34,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryActionGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: AppColors.glowShadow(
                    AppColors.primaryBright,
                    isDark: isDark,
                  ),
                ),
                child: const Icon(
                  Icons.point_of_sale_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              label: 'Kasir POS',
            ),
            const NavigationDestination(
              icon: Icon(Icons.people_outline_rounded),
              selectedIcon: Icon(Icons.people_rounded),
              label: 'Pelanggan',
            ),
            const NavigationDestination(
              icon: Icon(Icons.tune_rounded),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'Setelan',
            ),
          ],
        ),
      ),
    );
  }
}
