import 'package:flutter/material.dart';

import 'models/auth_user.dart';
import 'repositories/repositories.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'session.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  currentUser.addListener(() {
    apiClient.sessionId = currentUser.value?.sessionId;
  });
  await initSession();
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