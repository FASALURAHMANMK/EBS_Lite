import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_config.dart';

class AppEnvironment {
  const AppEnvironment({
    required this.apiBaseUrl,
    required this.appVersion,
    required this.buildNumber,
    required this.releaseDate,
    required this.releaseChannel,
    required this.updateUrl,
    required this.updatePolicy,
    required this.supportEmail,
    required this.supportPhone,
    required this.supportWebsite,
    required this.supportHours,
    required this.termsUrl,
    required this.privacyUrl,
  });

  static const String _definesAsset = 'dart_defines.production.json';

  static const String _compileApiBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');
  static const String _compileAppVersion =
      String.fromEnvironment('APP_VERSION', defaultValue: '');
  static const String _compileBuildNumber =
      String.fromEnvironment('BUILD_NUMBER', defaultValue: '');
  static const String _compileReleaseDate =
      String.fromEnvironment('RELEASE_DATE', defaultValue: '');
  static const String _compileReleaseChannel =
      String.fromEnvironment('RELEASE_CHANNEL', defaultValue: '');
  static const String _compileUpdateUrl =
      String.fromEnvironment('UPDATE_URL', defaultValue: '');
  static const String _compileUpdatePolicy =
      String.fromEnvironment('UPDATE_POLICY', defaultValue: '');
  static const String _compileSupportEmail =
      String.fromEnvironment('SUPPORT_EMAIL', defaultValue: '');
  static const String _compileSupportPhone =
      String.fromEnvironment('SUPPORT_PHONE', defaultValue: '');
  static const String _compileSupportWebsite =
      String.fromEnvironment('SUPPORT_WEBSITE', defaultValue: '');
  static const String _compileSupportHours =
      String.fromEnvironment('SUPPORT_HOURS', defaultValue: '');
  static const String _compileTermsUrl =
      String.fromEnvironment('SUPPORT_TERMS_URL', defaultValue: '');
  static const String _compilePrivacyUrl =
      String.fromEnvironment('SUPPORT_PRIVACY_URL', defaultValue: '');

  final String apiBaseUrl;
  final String appVersion;
  final String buildNumber;
  final String releaseDate;
  final String releaseChannel;
  final String updateUrl;
  final String updatePolicy;
  final String supportEmail;
  final String supportPhone;
  final String supportWebsite;
  final String supportHours;
  final String termsUrl;
  final String privacyUrl;

  static Future<AppEnvironment> load({
    AssetBundle? bundle,
  }) async {
    final fileValues = await _loadFileValues(bundle ?? rootBundle);
    return AppEnvironment(
      apiBaseUrl: AppConfig.resolveApiBaseUrl(
        configuredValue: _resolveValue(
          key: 'API_BASE_URL',
          fileValues: fileValues,
          compileValue: _compileApiBaseUrl,
        ),
        isReleaseMode: kReleaseMode,
      ),
      appVersion: _resolveValue(
        key: 'APP_VERSION',
        fileValues: fileValues,
        compileValue: _compileAppVersion,
        fallback: 'unknown',
      ),
      buildNumber: _resolveValue(
        key: 'BUILD_NUMBER',
        fileValues: fileValues,
        compileValue: _compileBuildNumber,
        fallback: 'unknown',
      ),
      releaseDate: _resolveValue(
        key: 'RELEASE_DATE',
        fileValues: fileValues,
        compileValue: _compileReleaseDate,
        fallback: 'Not configured',
      ),
      releaseChannel: _resolveValue(
        key: 'RELEASE_CHANNEL',
        fileValues: fileValues,
        compileValue: _compileReleaseChannel,
        fallback: 'Production',
      ),
      updateUrl: _resolveValue(
        key: 'UPDATE_URL',
        fileValues: fileValues,
        compileValue: _compileUpdateUrl,
      ),
      updatePolicy: _resolveValue(
        key: 'UPDATE_POLICY',
        fileValues: fileValues,
        compileValue: _compileUpdatePolicy,
      ),
      supportEmail: _resolveValue(
        key: 'SUPPORT_EMAIL',
        fileValues: fileValues,
        compileValue: _compileSupportEmail,
      ),
      supportPhone: _resolveValue(
        key: 'SUPPORT_PHONE',
        fileValues: fileValues,
        compileValue: _compileSupportPhone,
      ),
      supportWebsite: _resolveValue(
        key: 'SUPPORT_WEBSITE',
        fileValues: fileValues,
        compileValue: _compileSupportWebsite,
      ),
      supportHours: _resolveValue(
        key: 'SUPPORT_HOURS',
        fileValues: fileValues,
        compileValue: _compileSupportHours,
      ),
      termsUrl: _resolveValue(
        key: 'SUPPORT_TERMS_URL',
        fileValues: fileValues,
        compileValue: _compileTermsUrl,
      ),
      privacyUrl: _resolveValue(
        key: 'SUPPORT_PRIVACY_URL',
        fileValues: fileValues,
        compileValue: _compilePrivacyUrl,
      ),
    );
  }

  static Future<Map<String, dynamic>> _loadFileValues(
      AssetBundle bundle) async {
    try {
      final raw = await bundle.loadString(_definesAsset);
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Runtime config falls back to compile-time defines and safe defaults.
    }
    return const <String, dynamic>{};
  }

  static String _resolveValue({
    required String key,
    required Map<String, dynamic> fileValues,
    required String compileValue,
    String fallback = '',
  }) {
    final compileTrimmed = compileValue.trim();
    if (compileTrimmed.isNotEmpty) {
      return compileTrimmed;
    }

    final fileValue = fileValues[key];
    if (fileValue is String && fileValue.trim().isNotEmpty) {
      return fileValue.trim();
    }

    return fallback;
  }
}

final appEnvironmentProvider = Provider<AppEnvironment>((ref) {
  throw UnimplementedError('AppEnvironment has not been initialized.');
});
