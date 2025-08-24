import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'models.dart';

class AuthRepository {
  AuthRepository(this._dio, this._prefs);
  final Dio _dio;
  final SharedPreferences _prefs;

  static const _deviceKey = 'device_id';
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

  Future<String> _getDeviceId() async {
    var id = _prefs.getString(_deviceKey);
    if (id == null) {
      id = const Uuid().v4();
      await _prefs.setString(_deviceKey, id);
    }
    return id;
  }

  Future<LoginResponse> login({
    String? username,
    String? email,
    required String password,
  }) async {
    final deviceId = await _getDeviceId();
    final payload = <String, dynamic>{
      'password': password,
      'device_id': deviceId,
    };
    if (username != null && username.isNotEmpty) {
      payload['username'] = username;
    }
    if (email != null && email.isNotEmpty) {
      payload['email'] = email;
    }
    final response = await _dio.post('/auth/login', data: payload);
    final data =
        LoginResponse.fromJson(response.data['data'] as Map<String, dynamic>);
    await _prefs.setString(_accessTokenKey, data.accessToken);
    await _prefs.setString(_refreshTokenKey, data.refreshToken);
    return data;
  }

  Future<RegisterResponse> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final response = await _dio.post('/auth/register', data: {
      'username': username,
      'email': email,
      'password': password,
    });
    return RegisterResponse.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  Future<void> forgotPassword(String email) async {
    await _dio.post('/auth/forgot-password', data: {'email': email});
  }

  Future<void> resetPassword({required String token, required String newPassword}) async {
    await _dio.post('/auth/reset-password', data: {
      'token': token,
      'new_password': newPassword,
    });
  }

  Future<Company> createCompany({required String name, String? email}) async {
    final token = _prefs.getString(_accessTokenKey);
    final response = await _dio.post('/companies',
        data: {'name': name, if (email != null) 'email': email},
        options: Options(headers: {'Authorization': 'Bearer $token'}));
    return Company.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }
}
