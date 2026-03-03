import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'dart:async';

/// Controls light and dark theme switching
class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier(this._prefs) : super(ThemeMode.system) {
    _load();
  }

  static const _key = 'theme_mode';
  final SharedPreferences _prefs;

  void _load() {
    final v = _prefs.getString(_key);
    if (v == null || v.isEmpty) return;
    switch (v) {
      case 'system':
        state = ThemeMode.system;
        break;
      case 'light':
        state = ThemeMode.light;
        break;
      case 'dark':
        state = ThemeMode.dark;
        break;
    }
  }

  void setMode(ThemeMode mode) {
    state = mode;
    unawaited(_prefs.setString(_key, mode.name));
  }

  /// Toggle between light and dark modes. Defaults to system brightness.
  void toggle() {
    setMode(state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light);
  }
}

final themeNotifierProvider =
    StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ThemeNotifier(prefs);
});
