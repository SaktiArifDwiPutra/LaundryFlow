import 'package:flutter/material.dart';

import 'models/auth_user.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'session.dart';

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
      home: ValueListenableBuilder<AuthUser?>(
        valueListenable: currentUser,
        builder: (context, user, _) =>
            user == null ? const LoginScreen() : const HomeScreen(),
      ),
    );
  }
}