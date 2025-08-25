import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/auth/data/auth_repository.dart';

class ApiClient {
  ApiClient(this._prefs, {String baseUrl = 'http://192.168.100.128:8080/api/v1'})
      : dio = Dio(BaseOptions(baseUrl: baseUrl)) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _prefs.getString(AuthRepository.accessTokenKey);
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            final refreshToken =
                _prefs.getString(AuthRepository.refreshTokenKey);
            if (refreshToken != null) {
              try {
                final refreshDio = Dio(BaseOptions(baseUrl: dio.options.baseUrl));
                final res = await refreshDio.post(
                  '/auth/refresh-token',
                  data: {'refresh_token': refreshToken},
                );
                final data = res.data['data'] as Map<String, dynamic>;
                final newAccess = data['access_token'] as String;
                final newRefresh = data['refresh_token'] as String;
                await _prefs.setString(
                    AuthRepository.accessTokenKey, newAccess);
                await _prefs.setString(
                    AuthRepository.refreshTokenKey, newRefresh);
                final sessionId = data['session_id'] as String?;
                if (sessionId != null) {
                  await _prefs.setString(
                      AuthRepository.sessionIdKey, sessionId);
                }
                final reqOptions = error.requestOptions;
                reqOptions.headers['Authorization'] = 'Bearer $newAccess';
                final cloneReq = await dio.fetch(reqOptions);
                return handler.resolve(cloneReq);
              } catch (e) {
                // If refreshing fails, forward the original error
              }
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  final SharedPreferences _prefs;
  final Dio dio;
}

// Providers for dependency injection
final dioProvider = Provider<Dio>((ref) {
  throw UnimplementedError();
});

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});
