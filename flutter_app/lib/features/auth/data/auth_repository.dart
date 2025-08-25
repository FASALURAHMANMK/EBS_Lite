import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'models.dart';

class AuthRepository {
  AuthRepository(this._dio, this._prefs);
  final Dio _dio;
  final SharedPreferences _prefs;

  static const _deviceKey = 'device_id';
  static const accessTokenKey = 'access_token';
  static const refreshTokenKey = 'refresh_token';
  static const sessionIdKey = 'session_id';
  static const companyKey = 'company';

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
    await _prefs.setString(accessTokenKey, data.accessToken);
    await _prefs.setString(refreshTokenKey, data.refreshToken);
    await _prefs.setString(sessionIdKey, data.sessionId);
    if (data.company != null) {
      await _prefs.setString(
        companyKey,
        jsonEncode({
          'company_id': data.company!.companyId,
          'name': data.company!.name,
        }),
      );
    } else {
      await _prefs.remove(companyKey);
    }
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
    final response = await _dio.post('/companies',
        data: {'name': name, if (email != null) 'email': email});
    final company =
        Company.fromJson(response.data['data'] as Map<String, dynamic>);
    await _prefs.setString(
      companyKey,
      jsonEncode({
        'company_id': company.companyId,
        'name': company.name,
      }),
    );
    return company;
  }

  Future<MeResponse> me() async {
    final response = await _dio.get('/auth/me');
    final data = MeResponse.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
    if (data.company != null) {
      await _prefs.setString(
        companyKey,
        jsonEncode({
          'company_id': data.company!.companyId,
          'name': data.company!.name,
        }),
      );
    } else {
      await _prefs.remove(companyKey);
    }
    return data;
  }
}
