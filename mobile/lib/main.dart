import 'package:flutter/material.dart';

import 'models/auth_user.dart';
import 'repositories/repositories.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'session.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  currentUser.addListener(() {
    apiClient.sessionId = currentUser.value?.sessionId;
  });
  await Future.wait([
    initSession(),
    themeController.init(),
  ]);
  runApp(const LaundryFlowApp());
}

class LaundryFlowApp extends StatelessWidget {
  const LaundryFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) {
        return MaterialApp(
          title: 'LaundryFlow',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeController.themeMode,
          home: ValueListenableBuilder<AuthUser?>(
            valueListenable: currentUser,
            builder: (context, user, _) =>
                user == null ? const LoginScreen() : const HomeScreen(),
          ),
        );
      },
    );
  }
}
