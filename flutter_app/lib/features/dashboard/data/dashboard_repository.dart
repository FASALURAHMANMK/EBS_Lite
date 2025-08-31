import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import 'models.dart';

class DashboardRepository {
  DashboardRepository(this._dio);
  final Dio _dio;

  Future<DashboardMetrics> getMetrics({int? locationId}) async {
    final res = await _dio.get(
      '/dashboard/metrics',
      queryParameters: locationId != null ? {'location_id': locationId} : null,
    );
    return DashboardMetrics.fromJson(
        res.data['data'] as Map<String, dynamic>);
  }

  Future<QuickActionCounts> getQuickActions({int? locationId}) async {
    final res = await _dio.get(
      '/dashboard/quick-actions',
      queryParameters: locationId != null ? {'location_id': locationId} : null,
    );
    return QuickActionCounts.fromJson(
        res.data['data'] as Map<String, dynamic>);
  }
}

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return DashboardRepository(dio);
});
