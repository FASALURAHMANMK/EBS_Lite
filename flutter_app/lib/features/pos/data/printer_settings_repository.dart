import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';

const _printerSettingsKey = 'printer_settings';

class PrinterSettings {
  final String connectionType; // e.g. 'network'
  final String? host; // for network
  final int? port; // for network
  final String paperSize; // '58mm' | '80mm'

  const PrinterSettings({
    required this.connectionType,
    required this.paperSize,
    this.host,
    this.port,
  });

  factory PrinterSettings.fromJson(Map<String, dynamic> json) => PrinterSettings(
        connectionType: json['connection_type'] as String? ?? 'network',
        host: json['host'] as String?,
        port: (json['port'] as num?)?.toInt(),
        paperSize: json['paper_size'] as String? ?? '80mm',
      );

  Map<String, dynamic> toJson() => {
        'connection_type': connectionType,
        if (host != null) 'host': host,
        if (port != null) 'port': port,
        'paper_size': paperSize,
      };
}

class PrinterSettingsRepository {
  PrinterSettingsRepository(this._ref);
  final Ref _ref;

  Future<PrinterSettings?> load() async {
    final prefs = _ref.read(sharedPreferencesProvider);
    final str = prefs.getString(_printerSettingsKey);
    if (str == null || str.isEmpty) return null;
    try {
      final map = jsonDecode(str) as Map<String, dynamic>;
      return PrinterSettings.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(PrinterSettings settings) async {
    final prefs = _ref.read(sharedPreferencesProvider);
    await prefs.setString(_printerSettingsKey, jsonEncode(settings.toJson()));
  }

  Future<void> clear() async {
    final prefs = _ref.read(sharedPreferencesProvider);
    await prefs.remove(_printerSettingsKey);
  }
}

final printerSettingsRepositoryProvider = Provider<PrinterSettingsRepository>((ref) {
  return PrinterSettingsRepository(ref);
});

