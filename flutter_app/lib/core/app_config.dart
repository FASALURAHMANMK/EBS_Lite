import 'package:flutter/foundation.dart';

class AppConfig {
  static const String _defaultApiBaseUrl = 'http://127.0.0.1:8080/api/v1';

  static String get apiBaseUrl {
    const value = String.fromEnvironment('API_BASE_URL',
        defaultValue: _defaultApiBaseUrl);
    return resolveApiBaseUrl(
      configuredValue: value,
      isReleaseMode: kReleaseMode,
    );
  }

  static String resolveApiBaseUrl({
    required String configuredValue,
    required bool isReleaseMode,
  }) {
    final trimmed = configuredValue.trim();
    final resolved = trimmed.isEmpty ? _defaultApiBaseUrl : trimmed;

    if (isReleaseMode && _isLocalHostUrl(resolved)) {
      throw StateError(
        'Release builds must define a non-local API_BASE_URL. '
        'Use flutter_app/dart_defines.production.example.json as the baseline.',
      );
    }

    return resolved;
  }

  static bool _isLocalHostUrl(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.contains('localhost') ||
        normalized.contains('127.0.0.1') ||
        normalized.contains('0.0.0.0');
  }
}
