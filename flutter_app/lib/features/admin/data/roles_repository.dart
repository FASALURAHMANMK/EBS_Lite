import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';

class RoleDto {
  final int roleId;
  final String name;
  final String description;
  final bool isSystemRole;

  const RoleDto({
    required this.roleId,
    required this.name,
    required this.description,
    required this.isSystemRole,
  });

  factory RoleDto.fromJson(Map<String, dynamic> json) => RoleDto(
        roleId: (json['role_id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        isSystemRole: json['is_system_role'] as bool? ?? false,
      );
}

class PermissionDto {
  final int permissionId;
  final String name;
  final String description;
  final String module;
  final String action;

  const PermissionDto({
    required this.permissionId,
    required this.name,
    required this.description,
    required this.module,
    required this.action,
  });

  factory PermissionDto.fromJson(Map<String, dynamic> json) => PermissionDto(
        permissionId: (json['permission_id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        module: json['module'] as String? ?? '',
        action: json['action'] as String? ?? '',
      );
}

class RoleWithPermissionsDto {
  final RoleDto role;
  final List<PermissionDto> permissions;

  const RoleWithPermissionsDto({required this.role, required this.permissions});

  factory RoleWithPermissionsDto.fromJson(Map<String, dynamic> json) {
    final role = RoleDto.fromJson(json);
    final perms = (json['permissions'] as List<dynamic>? ?? const [])
        .map((e) => PermissionDto.fromJson(e as Map<String, dynamic>))
        .toList();
    return RoleWithPermissionsDto(role: role, permissions: perms);
  }
}

class RolesRepository {
  RolesRepository(this._dio);
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

  Future<List<RoleDto>> listRoles() async {
    final res = await _dio.get('/roles');
    return _extractList(res.data)
        .map((e) => RoleDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<RoleDto> createRole(
      {required String name, String? description}) async {
    final res = await _dio.post('/roles', data: {
      'name': name,
      'description': description ?? '',
    });
    return RoleDto.fromJson(_extractDataMap(res.data));
  }

  Future<void> updateRole({
    required int roleId,
    String? name,
    String? description,
  }) async {
    await _dio.put('/roles/$roleId', data: {
      if (name != null) 'name': name,
      if (description != null) 'description': description,
    });
  }

  Future<void> deleteRole(int roleId) async {
    await _dio.delete('/roles/$roleId');
  }

  Future<List<PermissionDto>> listPermissions() async {
    final res = await _dio.get('/permissions');
    return _extractList(res.data)
        .map((e) => PermissionDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<RoleWithPermissionsDto> getRolePermissions(int roleId) async {
    final res = await _dio.get('/roles/$roleId/permissions');
    return RoleWithPermissionsDto.fromJson(_extractDataMap(res.data));
  }

  Future<void> assignPermissions(int roleId, List<int> permissionIds) async {
    await _dio.post('/roles/$roleId/permissions', data: {
      'permission_ids': permissionIds,
    });
  }
}

final rolesRepositoryProvider = Provider<RolesRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return RolesRepository(dio);
});
