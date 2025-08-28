import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api_client.dart';

class QuickActionVisibilityNotifier extends StateNotifier<bool> {
  QuickActionVisibilityNotifier(this._prefs) : super(true) {
    _load();
  }

  static const _key = 'show_quick_actions';
  final SharedPreferences _prefs;

  void _load() {
    final v = _prefs.getBool(_key);
    if (v != null) state = v;
  }

  Future<void> setVisible(bool value) async {
    state = value;
    await _prefs.setBool(_key, value);
  }
}

final quickActionVisibilityProvider =
    StateNotifierProvider<QuickActionVisibilityNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return QuickActionVisibilityNotifier(prefs);
});

