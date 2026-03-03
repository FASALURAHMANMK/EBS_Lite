import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';

class DeviceSessionDto {
  final String sessionId;
  final int userId;
  final String deviceId;
  final String? deviceName;
  final String? ipAddress;
  final String? userAgent;
  final DateTime? lastSeen;
  final DateTime? lastSyncTime;
  final bool isActive;
  final bool isStale;
  final DateTime? createdAt;

  const DeviceSessionDto({
    required this.sessionId,
    required this.userId,
    required this.deviceId,
    required this.deviceName,
    required this.ipAddress,
    required this.userAgent,
    required this.lastSeen,
    required this.lastSyncTime,
    required this.isActive,
    required this.isStale,
    required this.createdAt,
  });

  factory DeviceSessionDto.fromJson(Map<String, dynamic> json) =>
      DeviceSessionDto(
        sessionId: json['session_id'] as String? ?? '',
        userId: (json['user_id'] as num?)?.toInt() ?? 0,
        deviceId: json['device_id'] as String? ?? '',
        deviceName: json['device_name'] as String?,
        ipAddress: json['ip_address'] as String?,
        userAgent: json['user_agent'] as String?,
        lastSeen: DateTime.tryParse(json['last_seen'] as String? ?? ''),
        lastSyncTime:
            DateTime.tryParse(json['last_sync_time'] as String? ?? ''),
        isActive: json['is_active'] as bool? ?? true,
        isStale: json['is_stale'] as bool? ?? false,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      );
}

class DeviceSessionsRepository {
  DeviceSessionsRepository(this._dio);
  final Dio _dio;

  List<dynamic> _extractList(dynamic body) {
    if (body is List) return body;
    if (body is Map) {
      final data = body['data'];
      if (data is List) return data;
    }
    return const [];
  }

  Future<List<DeviceSessionDto>> listActiveSessions() async {
    final res = await _dio.get('/device-sessions');
    return _extractList(res.data)
        .map((e) => DeviceSessionDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> revokeSession(String sessionId) async {
    await _dio.delete('/device-sessions/$sessionId');
  }
}

final deviceSessionsRepositoryProvider =
    Provider<DeviceSessionsRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return DeviceSessionsRepository(dio);
});
