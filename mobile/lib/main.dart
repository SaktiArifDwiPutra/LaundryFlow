import 'package:flutter/material.dart';
import 'screens/order_list_screen.dart';

void main() {
  runApp(const LaundryFlowApp());
}

class LaundryFlowApp extends StatelessWidget {
  const LaundryFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LaundryFlow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: const OrderListScreen(),
    );
  }
}