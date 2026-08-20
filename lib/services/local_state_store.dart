import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStateStore extends ChangeNotifier {
  LocalStateStore._(this._preferences) {
    _themeMode = _readThemeMode(_preferences.getString(_themeModeKey));
  }

  static const _themeModeKey = 'theme_mode';

  final SharedPreferences _preferences;
  late ThemeMode _themeMode;

  static Future<LocalStateStore> load() async {
    return LocalStateStore._(await SharedPreferences.getInstance());
  }

  ThemeMode get themeMode => _themeMode;

  void setThemeMode(ThemeMode themeMode) {
    if (_themeMode == themeMode) return;
    _themeMode = themeMode;
    unawaited(_preferences.setString(_themeModeKey, themeMode.name));
    notifyListeners();
  }

  static ThemeMode _readThemeMode(String? value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
  }
}
