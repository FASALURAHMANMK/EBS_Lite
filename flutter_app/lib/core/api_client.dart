import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/auth/data/auth_repository.dart';
import 'auth_events.dart';

class ApiClient {
  ApiClient(
    this._prefs,
    this._secureStorage, {
    //String baseUrl = 'http://192.168.100.128:8080/api/v1',
    String baseUrl = 'http://127.0.0.1:8080/api/v1',
    //String baseUrl = 'http://10.0.2.2:8080/api/v1',
  }) : dio = Dio(BaseOptions(baseUrl: baseUrl)) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token =
              await _secureStorage.read(key: AuthRepository.accessTokenKey);
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          // Avoid trying to refresh for the refresh endpoint itself
          final path = error.requestOptions.path;
          final isRefreshCall = path.contains('/auth/refresh-token');

          if (error.response?.statusCode == 401 && !isRefreshCall) {
            try {
              await _refreshTokenSingleFlight();
              final newAccess =
                  await _secureStorage.read(key: AuthRepository.accessTokenKey);
              if (newAccess != null && newAccess.isNotEmpty) {
                final reqOptions = error.requestOptions;
                reqOptions.headers['Authorization'] = 'Bearer $newAccess';
                final cloneReq = await dio.fetch(reqOptions);
                return handler.resolve(cloneReq);
              }
            } catch (_) {
              // fall-through to handler.next(error)
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secureStorage;
  final Dio dio;

  Future<void>? _refreshing;

  Future<void> _refreshTokenSingleFlight() {
    final existing = _refreshing;
    if (existing != null) return existing;
    final f = _doRefresh().whenComplete(() => _refreshing = null);
    _refreshing = f;
    return f;
  }

  Future<void> _doRefresh() async {
    final refreshToken =
        await _secureStorage.read(key: AuthRepository.refreshTokenKey);
    if (refreshToken == null || refreshToken.isEmpty) {
      await _purgeTokens();
      throw DioException(
        requestOptions: RequestOptions(path: '/auth/refresh-token'),
        error: 'No refresh token',
      );
    }

    try {
      final refreshDio = Dio(BaseOptions(baseUrl: dio.options.baseUrl));
      final res = await refreshDio.post(
        '/auth/refresh-token',
        data: {'refresh_token': refreshToken},
      );
      final data = res.data['data'] as Map<String, dynamic>;
      final newAccess = data['access_token'] as String;
      // Backend returns only access_token for refresh. Keep existing
      // refresh token and session id unchanged.
      await _secureStorage.write(
          key: AuthRepository.accessTokenKey, value: newAccess);
    } catch (e) {
      await _purgeTokens();
      // Notify app to reset auth state and navigate out
      AuthEvents.instance.broadcastLogout();
      rethrow;
    }
  }

  Future<void> _purgeTokens() async {
    await _secureStorage.delete(key: AuthRepository.accessTokenKey);
    await _secureStorage.delete(key: AuthRepository.refreshTokenKey);
    await _secureStorage.delete(key: AuthRepository.sessionIdKey);
    await _prefs.remove(AuthRepository.companyKey);
  }
}

// Providers for dependency injection
final dioProvider = Provider<Dio>((ref) {
  throw UnimplementedError();
});

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});
