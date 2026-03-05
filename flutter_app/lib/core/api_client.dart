import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/auth/data/auth_repository.dart';
import 'app_config.dart';
import 'auth_events.dart';

class ApiClient {
  ApiClient(
    this._prefs,
    this._secureStorage, {
    String? baseUrl,
  }) : dio = Dio(BaseOptions(baseUrl: _resolveBaseUrl(baseUrl))) {
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
    } on DioException catch (e) {
      // Important for offline-first:
      // - If refresh fails due to *network issues* or transient server errors,
      //   do NOT purge tokens or force logout. Let the original request fail
      //   and allow the app to continue in offline mode.
      // - Only purge+logout when the refresh token is actually invalid.
      final code = e.response?.statusCode;
      final invalidRefresh = code == 400 || code == 401 || code == 403;
      final isNetwork = _isNetworkError(e);

      if (invalidRefresh) {
        await _purgeTokens();
        AuthEvents.instance.broadcastLogout();
      } else if (!isNetwork && code != null && code >= 500) {
        // Keep session; server is reachable but unstable.
      } else if (!isNetwork && code == null) {
        // Unknown failure; keep tokens to avoid breaking offline mode.
      }
      rethrow;
    } catch (_) {
      // Any unexpected error: keep tokens so the UI can continue offline.
      rethrow;
    }
  }

  bool _isNetworkError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.unknown:
        return e.error is SocketException;
      case DioExceptionType.badResponse:
      case DioExceptionType.badCertificate:
      case DioExceptionType.cancel:
        return false;
    }
  }

  Future<void> _purgeTokens() async {
    await AuthRepository.purgeLocalSession(_prefs, _secureStorage);
  }

  static String _resolveBaseUrl(String? override) {
    final candidate = (override ?? AppConfig.apiBaseUrl).trim();
    return candidate.isEmpty ? AppConfig.apiBaseUrl : candidate;
  }
}

// Providers for dependency injection
final dioProvider = Provider<Dio>((ref) {
  throw UnimplementedError();
});

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});
