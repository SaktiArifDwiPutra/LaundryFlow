import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/auth_user.dart';

const String _userPrefsKey = 'laundryflow_saved_user';

final ValueNotifier<AuthUser?> currentUser = ValueNotifier<AuthUser?>(null);

Future<void> initSession() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_userPrefsKey);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      final data = jsonDecode(jsonStr);
      if (data is Map<String, dynamic>) {
        currentUser.value = AuthUser.fromJson(data);
      }
    }
  } catch (e) {
    debugPrint('Gagal memuat sesi tersimpan: $e');
  }
}

Future<void> saveSession(AuthUser user) async {
  currentUser.value = user;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userPrefsKey, jsonEncode(user.toJson()));
  } catch (e) {
    debugPrint('Gagal menyimpan sesi: $e');
  }
}

Future<void> clearSession() async {
  currentUser.value = null;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userPrefsKey);
  } catch (e) {
    debugPrint('Gagal menghapus sesi: $e');
  }
}
