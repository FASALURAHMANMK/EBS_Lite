import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import 'settings_models.dart';

class SettingsRepository {
  SettingsRepository(this._dio);
  final Dio _dio;

  Map<String, dynamic> _extractDataMap(dynamic body) {
    if (body is Map<String, dynamic>) {
      final d = body['data'];
      if (d is Map<String, dynamic>) return d;
      return const {};
    }
    return const {};
  }

  Future<CompanySettingsDto> getCompanySettings() async {
    final res = await _dio.get('/settings/company');
    return CompanySettingsDto.fromJson(_extractDataMap(res.data));
  }

  Future<void> updateCompanySettings(CompanySettingsDto cfg) async {
    await _dio.put('/settings/company', data: cfg.toJson());
  }

  Future<InventorySettingsDto> getInventorySettings() async {
    final res = await _dio.get('/settings/inventory');
    return InventorySettingsDto.fromJson(_extractDataMap(res.data));
  }

  Future<void> updateInventorySettings(UpdateInventorySettingsDto cfg) async {
    await _dio.put('/settings/inventory', data: cfg.toJson());
  }

  Future<InvoiceSettingsDto> getInvoiceSettings() async {
    final res = await _dio.get('/settings/invoice');
    return InvoiceSettingsDto.fromJson(_extractDataMap(res.data));
  }

  Future<void> updateInvoiceSettings(InvoiceSettingsDto cfg) async {
    await _dio.put('/settings/invoice', data: cfg.toJson());
  }

  Future<TaxSettingsDto> getTaxSettings() async {
    final res = await _dio.get('/settings/tax');
    return TaxSettingsDto.fromJson(_extractDataMap(res.data));
  }

  Future<void> updateTaxSettings(TaxSettingsDto cfg) async {
    await _dio.put('/settings/tax', data: cfg.toJson());
  }

  Future<DeviceControlSettingsDto> getDeviceControlSettings() async {
    final res = await _dio.get('/settings/device-control');
    return DeviceControlSettingsDto.fromJson(_extractDataMap(res.data));
  }

  Future<void> updateDeviceControlSettings(DeviceControlSettingsDto cfg) async {
    await _dio.put('/settings/device-control', data: cfg.toJson());
  }

  Future<SessionLimitDto> getSessionLimit() async {
    final res = await _dio.get('/settings/session-limit');
    return SessionLimitDto.fromJson(_extractDataMap(res.data));
  }

  Future<void> setSessionLimit(int maxSessions) async {
    await _dio
        .put('/settings/session-limit', data: {'max_sessions': maxSessions});
  }

  Future<void> deleteSessionLimit() async {
    await _dio.delete('/settings/session-limit');
  }
}

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return SettingsRepository(dio);
});
