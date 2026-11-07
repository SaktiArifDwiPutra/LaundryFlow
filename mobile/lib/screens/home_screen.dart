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

  Widget _buildBody() {
    switch (_index) {
      case 0:
        return QueueScreen(key: _queueKey);
      case 1:
        return OrderListScreen(key: _orderListKey);
      case 3:
        return const CustomerListScreen();
      case 4:
        return const SettingsScreen();
      default:
        return QueueScreen(key: _queueKey);
    }
  }

  Future<void> _openNewOrder() async {
    final created = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NewOrderScreen()),
    );
    if (created != null && mounted) {
      // If we are on Queue or Orders, switch or refresh
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          if (i == 2) {
            _openNewOrder();
            return;
          }
          setState(() => _index = i);
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Antrian',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Pesanan',
          ),
          NavigationDestination(
            icon: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.add,
                color: Colors.white,
                size: 20,
              ),
            ),
            label: 'Buat Baru',
          ),
          const NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Pelanggan',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Setelan',
          ),
        ],
      ),
    );
  }
}
