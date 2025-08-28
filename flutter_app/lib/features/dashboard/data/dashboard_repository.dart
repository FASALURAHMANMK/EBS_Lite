import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import 'models.dart';

class DashboardRepository {
  DashboardRepository(this._dio);
  final Dio _dio;

  Future<DashboardMetrics> getMetrics() async {
    final res = await _dio.get('/dashboard/metrics');
    return DashboardMetrics.fromJson(
        res.data['data'] as Map<String, dynamic>);
  }

  Future<QuickActionCounts> getQuickActions() async {
    final res = await _dio.get('/dashboard/quick-actions');
    return QuickActionCounts.fromJson(
        res.data['data'] as Map<String, dynamic>);
  }
}

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return DashboardRepository(dio);
});
