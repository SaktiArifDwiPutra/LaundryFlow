import 'package:flutter/material.dart';

import 'customer_list_screen.dart';
import 'order_list_screen.dart';
import 'queue_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  Widget get _page => switch (_index) {
        0 => const QueueScreen(),
        1 => const OrderListScreen(),
        _ => const CustomerListScreen(),
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _page,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.format_list_numbered),
            label: 'Antrian',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_laundry_service_outlined),
            selectedIcon: Icon(Icons.local_laundry_service),
            label: 'Pesanan',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Pelanggan',
          ),
        ],
      ),
    );
  }
}