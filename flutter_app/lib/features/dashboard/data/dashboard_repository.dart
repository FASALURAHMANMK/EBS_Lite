import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api_client.dart';
import '../../auth/data/auth_repository.dart';
import 'models.dart';

class DashboardRepository {
  DashboardRepository(this._dio, this._prefs);
  final Dio _dio;
  final SharedPreferences _prefs;

  Map<String, String> _authHeader() {
    final token = _prefs.getString(AuthRepository.accessTokenKey);
    return {
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<DashboardMetrics> getMetrics() async {
    final res = await _dio.get(
      '/dashboard/metrics',
      options: Options(headers: _authHeader()),
    );
    return DashboardMetrics.fromJson(
        res.data['data'] as Map<String, dynamic>);
  }

  Future<QuickActionCounts> getQuickActions() async {
    final res = await _dio.get(
      '/dashboard/quick-actions',
      options: Options(headers: _authHeader()),
    );
    return QuickActionCounts.fromJson(
        res.data['data'] as Map<String, dynamic>);
  }
}

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return DashboardRepository(dio, prefs);
});
