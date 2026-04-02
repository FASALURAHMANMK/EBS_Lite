import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'region_options.dart';

class LocalePreferencesState {
  final Locale uiLocale;
  final Locale receiptLocale;
  final String countryCode;
  final String? timeZoneId;

  const LocalePreferencesState({
    required this.uiLocale,
    required this.receiptLocale,
    required this.countryCode,
    required this.timeZoneId,
  });

  LocalePreferencesState copyWith({
    Locale? uiLocale,
    Locale? receiptLocale,
    String? countryCode,
    String? timeZoneId,
    bool clearTimeZoneId = false,
  }) {
    return LocalePreferencesState(
      uiLocale: uiLocale ?? this.uiLocale,
      receiptLocale: receiptLocale ?? this.receiptLocale,
      countryCode: countryCode ?? this.countryCode,
      timeZoneId: clearTimeZoneId ? null : (timeZoneId ?? this.timeZoneId),
    );
  }

  String get formatLocaleTag {
    final country = countryCode.trim().toUpperCase();
    if (country.isEmpty) {
      return uiLocale.languageCode;
    }
    return '${uiLocale.languageCode}_$country';
  }
}

class LocalePreferencesNotifier extends StateNotifier<LocalePreferencesState> {
  LocalePreferencesNotifier(this._prefs)
      : super(LocalePreferencesState(
          uiLocale: const Locale('en'),
          receiptLocale: const Locale('en'),
          countryCode: _defaultCountryCode(),
          timeZoneId: null,
        )) {
    _load();
  }

  static const supportedLocales = <Locale>[
    Locale('en'),
    Locale('ar'),
  ];

  static const _uiLocaleKey = 'ui_locale';
  static const _receiptLocaleKey = 'receipt_locale';
  static const _countryCodeKey = 'region_country_code';
  static const _timeZoneIdKey = 'region_time_zone_id';

  final SharedPreferences _prefs;

  void _load() {
    final uiCode = _prefs.getString(_uiLocaleKey);
    final receiptCode = _prefs.getString(_receiptLocaleKey);
    final countryCode = _normalizeCountryCode(
      _prefs.getString(_countryCodeKey),
    );
    final timeZoneId = _normalizeTimeZoneId(
      _prefs.getString(_timeZoneIdKey),
    );
    final uiLocale = _parseLocale(uiCode);
    final receiptLocale = _parseLocale(receiptCode);
    state = state.copyWith(
      uiLocale: uiLocale ?? state.uiLocale,
      receiptLocale: receiptLocale ?? state.receiptLocale,
      countryCode: countryCode ?? state.countryCode,
      timeZoneId: timeZoneId,
      clearTimeZoneId: timeZoneId == null,
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

  Future<void> setCountryCode(String countryCode) async {
    final normalized =
        _normalizeCountryCode(countryCode) ?? _defaultCountryCode();
    state = state.copyWith(countryCode: normalized);
    await _prefs.setString(_countryCodeKey, normalized);
  }

  Future<void> setTimeZoneId(String? timeZoneId) async {
    final normalized = _normalizeTimeZoneId(timeZoneId);
    state = state.copyWith(
      timeZoneId: normalized,
      clearTimeZoneId: normalized == null,
    );
    if (normalized == null) {
      await _prefs.remove(_timeZoneIdKey);
      return;
    }
    await _prefs.setString(_timeZoneIdKey, normalized);
  }

  Locale? _parseLocale(String? code) {
    if (code == null) return null;
    final trimmed = code.trim();
    if (trimmed.isEmpty) return null;
    return Locale(trimmed);
  }

  static String _defaultCountryCode() {
    final deviceCode = PlatformDispatcher.instance.locale.countryCode;
    return _normalizeCountryCode(deviceCode) ?? 'US';
  }

  static String? _normalizeCountryCode(String? code) {
    if (code == null || code.trim().isEmpty) {
      return null;
    }
    final normalized = code.trim().toUpperCase();
    if (!isSupportedCountryCode(normalized)) {
      return null;
    }
    return normalized;
  }

  static String? _normalizeTimeZoneId(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return trimmed;
  }
}

final localePreferencesProvider =
    StateNotifierProvider<LocalePreferencesNotifier, LocalePreferencesState>(
        (ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return LocalePreferencesNotifier(prefs);
});
