import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import 'settings_models.dart';

class SettingsRepository {
  SettingsRepository(this._dio);
  final Dio _dio;

  Future<CompanySettingsDto> getCompanySettings() async {
    final res = await _dio.get('/settings/company');
    final body = res.data;
    Map<String, dynamic> data = const {};
    if (body is Map<String, dynamic>) {
      final d = body['data'];
      if (d is Map<String, dynamic>) {
        data = d;
      }
    }
    return CompanySettingsDto.fromJson(data);
  }

  Future<void> updateCompanySettings(CompanySettingsDto cfg) async {
    await _dio.put('/settings/company', data: cfg.toJson());
  }
}

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return SettingsRepository(dio);
});
