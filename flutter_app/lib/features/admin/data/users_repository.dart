import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';

class AdminUserDto {
  final int userId;
  final String username;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final int? roleId;
  final int? locationId;
  final int? companyId;
  final bool isActive;
  final bool isLocked;
  final DateTime? lastLogin;

  const AdminUserDto({
    required this.userId,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.roleId,
    required this.locationId,
    required this.companyId,
    required this.isActive,
    required this.isLocked,
    required this.lastLogin,
  });

  factory AdminUserDto.fromJson(Map<String, dynamic> json) => AdminUserDto(
        userId: (json['user_id'] as num?)?.toInt() ?? 0,
        username: json['username'] as String? ?? '',
        email: json['email'] as String? ?? '',
        firstName: json['first_name'] as String?,
        lastName: json['last_name'] as String?,
        phone: json['phone'] as String?,
        roleId: (json['role_id'] as num?)?.toInt(),
        locationId: (json['location_id'] as num?)?.toInt(),
        companyId: (json['company_id'] as num?)?.toInt(),
        isActive: json['is_active'] as bool? ?? true,
        isLocked: json['is_locked'] as bool? ?? false,
        lastLogin: DateTime.tryParse(json['last_login'] as String? ?? ''),
      );
}

class UsersRepository {
  UsersRepository(this._dio);
  final Dio _dio;

  List<dynamic> _extractList(dynamic body) {
    if (body is List) return body;
    if (body is Map) {
      final data = body['data'];
      if (data is List) return data;
    }
    return const [];
  }

  Map<String, dynamic> _extractDataMap(dynamic body) {
    if (body is Map<String, dynamic>) {
      final d = body['data'];
      if (d is Map<String, dynamic>) return d;
      return body;
    }
    return const {};
  }

  Future<List<AdminUserDto>> listUsers({int? locationId}) async {
    final res = await _dio.get(
      '/users',
      queryParameters: {
        if (locationId != null) 'location_id': locationId,
      },
    );
    return _extractList(res.data)
        .map((e) => AdminUserDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AdminUserDto> createUser({
    required int companyId,
    required String username,
    required String email,
    required String password,
    String? firstName,
    String? lastName,
    String? phone,
    int? roleId,
    int? locationId,
  }) async {
    final res = await _dio.post('/users', data: {
      'company_id': companyId,
      'username': username,
      'email': email,
      'password': password,
      if (firstName != null) 'first_name': firstName,
      if (lastName != null) 'last_name': lastName,
      if (phone != null) 'phone': phone,
      if (roleId != null) 'role_id': roleId,
      if (locationId != null) 'location_id': locationId,
    });
    return AdminUserDto.fromJson(_extractDataMap(res.data));
  }

  Future<void> updateUser({
    required int userId,
    String? firstName,
    String? lastName,
    String? phone,
    int? roleId,
    int? locationId,
    bool? isActive,
    bool? isLocked,
  }) async {
    await _dio.put('/users/$userId', data: {
      if (firstName != null) 'first_name': firstName,
      if (lastName != null) 'last_name': lastName,
      if (phone != null) 'phone': phone,
      if (roleId != null) 'role_id': roleId,
      if (locationId != null) 'location_id': locationId,
      if (isActive != null) 'is_active': isActive,
      if (isLocked != null) 'is_locked': isLocked,
    });
  }

  Future<void> deleteUser(int userId) async {
    await _dio.delete('/users/$userId');
  }
}

final usersRepositoryProvider = Provider<UsersRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return UsersRepository(dio);
});
