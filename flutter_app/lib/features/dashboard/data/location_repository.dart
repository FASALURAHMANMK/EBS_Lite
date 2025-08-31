import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import 'models.dart';

class LocationRepository {
  LocationRepository(this._dio);

  final Dio _dio;

  Future<List<Location>> fetchLocations(int companyId) async {
    final res = await _dio.get(
      '/locations',
      queryParameters: {'company_id': companyId},
    );
    final data = res.data['data'] as List<dynamic>;
    return data
        .map((e) => Location.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return LocationRepository(dio);
});
