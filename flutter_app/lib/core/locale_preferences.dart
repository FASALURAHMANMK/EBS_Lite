import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

class LocalePreferencesState {
  final Locale uiLocale;
  final Locale receiptLocale;

  const LocalePreferencesState({
    required this.uiLocale,
    required this.receiptLocale,
  });

  LocalePreferencesState copyWith({
    Locale? uiLocale,
    Locale? receiptLocale,
  }) {
    return LocalePreferencesState(
      uiLocale: uiLocale ?? this.uiLocale,
      receiptLocale: receiptLocale ?? this.receiptLocale,
    );
  }
}

class LocalePreferencesNotifier extends StateNotifier<LocalePreferencesState> {
  LocalePreferencesNotifier(this._prefs)
      : super(const LocalePreferencesState(
          uiLocale: Locale('en'),
          receiptLocale: Locale('en'),
        )) {
    _load();
  }

  static const supportedLocales = <Locale>[
    Locale('en'),
    Locale('ar'),
  ];

  static const _uiLocaleKey = 'ui_locale';
  static const _receiptLocaleKey = 'receipt_locale';

  final SharedPreferences _prefs;

  void _load() {
    final uiCode = _prefs.getString(_uiLocaleKey);
    final receiptCode = _prefs.getString(_receiptLocaleKey);
    final uiLocale = _parseLocale(uiCode);
    final receiptLocale = _parseLocale(receiptCode);
    state = state.copyWith(
      uiLocale: uiLocale ?? state.uiLocale,
      receiptLocale: receiptLocale ?? state.receiptLocale,
    );
  }

  Future<void> setUiLocale(Locale locale) async {
    state = state.copyWith(uiLocale: locale);
    await _prefs.setString(_uiLocaleKey, locale.languageCode);
  }

  Future<void> setReceiptLocale(Locale locale) async {
    state = state.copyWith(receiptLocale: locale);
    await _prefs.setString(_receiptLocaleKey, locale.languageCode);
  }

  Locale? _parseLocale(String? code) {
    if (code == null) return null;
    final trimmed = code.trim();
    if (trimmed.isEmpty) return null;
    return Locale(trimmed);
  }
}

final localePreferencesProvider =
    StateNotifierProvider<LocalePreferencesNotifier, LocalePreferencesState>(
        (ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return LocalePreferencesNotifier(prefs);
});
