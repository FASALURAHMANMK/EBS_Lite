import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api_client.dart';
import '../../auth/data/auth_repository.dart';
import 'models.dart';

class LocationRepository {
  LocationRepository(this._dio, this._prefs);

  final Dio _dio;
  final SharedPreferences _prefs;

  Map<String, String> _authHeader() {
    final token = _prefs.getString(AuthRepository.accessTokenKey);
    return {
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<Location>> fetchLocations(int companyId) async {
    final res = await _dio.get(
      '/locations',
      queryParameters: {'company_id': companyId},
      options: Options(headers: _authHeader()),
    );
    final data = res.data['data'] as List<dynamic>;
    return data
        .map((e) => Location.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return LocationRepository(dio, prefs);
});
