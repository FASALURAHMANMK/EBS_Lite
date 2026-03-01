class AppConfig {
  static const String _defaultApiBaseUrl = 'http://127.0.0.1:8080/api/v1';

  static String get apiBaseUrl {
    const value = String.fromEnvironment('API_BASE_URL',
        defaultValue: _defaultApiBaseUrl);
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return _defaultApiBaseUrl;
    }
    return trimmed;
  }
}
