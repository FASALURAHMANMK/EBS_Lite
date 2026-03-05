import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';

class UserPreferencesRepository {
  UserPreferencesRepository(this._dio);

  final Dio _dio;

  Map<String, dynamic> _extractDataMap(dynamic body) {
    if (body is Map<String, dynamic>) {
      final d = body['data'];
      if (d is Map<String, dynamic>) return d;
      return const {};
    }
    return const {};
  }

  Future<Map<String, String>> getPreferences() async {
    final res = await _dio.get('/user-preferences');
    final data = _extractDataMap(res.data);
    return data.map(
      (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
    );
  }

  Future<void> upsertPreference({required String key, required String value}) {
    return _dio.put('/user-preferences', data: {'key': key, 'value': value});
  }

  Future<void> deletePreference(String key) {
    return _dio.delete('/user-preferences/$key');
  }
}

final userPreferencesRepositoryProvider = Provider<UserPreferencesRepository>(
  (ref) => UserPreferencesRepository(ref.watch(dioProvider)),
);
