import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _themePrefsKey = 'laundryflow_theme_mode';

/// Global Theme Controller for LaundryFlow Adaptive Theme
final ThemeController themeController = ThemeController();

class ThemeController extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_themePrefsKey);
      if (saved != null) {
        switch (saved) {
          case 'light':
            _themeMode = ThemeMode.light;
            break;
          case 'dark':
            _themeMode = ThemeMode.dark;
            break;
          case 'system':
          default:
            _themeMode = ThemeMode.system;
            break;
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Gagal memuat preferensi tema: $e');
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final modeStr = switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
      await prefs.setString(_themePrefsKey, modeStr);
    } catch (e) {
      debugPrint('Gagal menyimpan preferensi tema: $e');
    }
  }
}
