import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';

class DashboardRepository {
  DashboardRepository(this._dio);
  final Dio _dio;

  // Example placeholder method
  Future<Response<dynamic>> ping() {
    return _dio.get('/dashboard/ping');
  }
}

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return DashboardRepository(dio);
});
