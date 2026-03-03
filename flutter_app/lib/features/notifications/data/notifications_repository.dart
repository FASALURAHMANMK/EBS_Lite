import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../dashboard/controllers/location_notifier.dart';
import 'models.dart';

class NotificationsRepository {
  NotificationsRepository(this._dio, this._ref);
  final Dio _dio;
  final Ref _ref;

  int? get _locationId =>
      _ref.read(locationNotifierProvider).selected?.locationId;

  List<dynamic> _extractList(Response res) {
    final body = res.data;
    if (body is List) return body;
    if (body is Map) {
      final value = body['data'];
      if (value is List) return value;
      return const [];
    }
    return const [];
  }

  Map<String, dynamic> _extractMap(Response res) {
    final body = res.data;
    if (body is Map<String, dynamic>) {
      final data = body['data'];
      if (data is Map<String, dynamic>) return data;
      return body;
    }
    return const {};
  }

  Future<List<NotificationDto>> listNotifications({int? locationId}) async {
    final loc = locationId ?? _locationId;
    final qp = <String, dynamic>{};
    if (loc != null) qp['location_id'] = loc;
    final res = await _dio.get('/notifications',
        queryParameters: qp.isEmpty ? null : qp);
    final list = _extractList(res);
    return list
        .map((e) => NotificationDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> getUnreadCount({int? locationId}) async {
    final loc = locationId ?? _locationId;
    final qp = <String, dynamic>{};
    if (loc != null) qp['location_id'] = loc;
    final res = await _dio.get('/notifications/unread-count',
        queryParameters: qp.isEmpty ? null : qp);
    final data = _extractMap(res);
    return (data['unread'] as num?)?.toInt() ?? 0;
  }

  Future<void> markRead(List<String> keys) async {
    final body = {
      'keys': keys.where((k) => k.trim().isNotEmpty).toList(),
    };
    if ((body['keys'] as List).isEmpty) return;
    await _dio.post('/notifications/mark-read', data: body);
  }
}

final notificationsRepositoryProvider =
    Provider<NotificationsRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return NotificationsRepository(dio, ref);
});
