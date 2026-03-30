import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';

class WorkflowRequestEventDto {
  final int eventId;
  final int approvalId;
  final String eventType;
  final int? actorId;
  final String? actorName;
  final String? fromStatus;
  final String? toStatus;
  final String? remarks;
  final Map<String, dynamic> payload;
  final DateTime? createdAt;

  const WorkflowRequestEventDto({
    required this.eventId,
    required this.approvalId,
    required this.eventType,
    required this.actorId,
    required this.actorName,
    required this.fromStatus,
    required this.toStatus,
    required this.remarks,
    required this.payload,
    required this.createdAt,
  });

  factory WorkflowRequestEventDto.fromJson(Map<String, dynamic> json) =>
      WorkflowRequestEventDto(
        eventId: (json['event_id'] as num?)?.toInt() ?? 0,
        approvalId: (json['approval_id'] as num?)?.toInt() ?? 0,
        eventType: (json['event_type'] ?? '').toString(),
        actorId: (json['actor_id'] as num?)?.toInt(),
        actorName: json['actor_name'] as String?,
        fromStatus: json['from_status'] as String?,
        toStatus: json['to_status'] as String?,
        remarks: json['remarks'] as String?,
        payload: (json['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
        createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
      );
}

class WorkflowRequestDto {
  final int approvalId;
  final int? locationId;
  final String module;
  final String entityType;
  final int? entityId;
  final String actionType;
  final String title;
  final String? summary;
  final String? requestReason;
  final String status;
  final String priority;
  final int approverRoleId;
  final String? approverRoleName;
  final Map<String, dynamic> payload;
  final Map<String, dynamic> resultSnapshot;
  final DateTime? dueAt;
  final bool isOverdue;
  final int escalationLevel;
  final int createdBy;
  final String? createdByName;
  final int? updatedBy;
  final int? approvedBy;
  final String? approvedByName;
  final DateTime? approvedAt;
  final String? decisionReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<WorkflowRequestEventDto> events;

  const WorkflowRequestDto({
    required this.approvalId,
    required this.locationId,
    required this.module,
    required this.entityType,
    required this.entityId,
    required this.actionType,
    required this.title,
    required this.summary,
    required this.requestReason,
    required this.status,
    required this.priority,
    required this.approverRoleId,
    required this.approverRoleName,
    required this.payload,
    required this.resultSnapshot,
    required this.dueAt,
    required this.isOverdue,
    required this.escalationLevel,
    required this.createdBy,
    required this.createdByName,
    required this.updatedBy,
    required this.approvedBy,
    required this.approvedByName,
    required this.approvedAt,
    required this.decisionReason,
    required this.createdAt,
    required this.updatedAt,
    required this.events,
  });

  bool get isPending => status.toUpperCase() == 'PENDING';

  String get entityLabel {
    final entity = entityType.replaceAll('_', ' ').trim();
    if (entityId == null || entityId == 0) return entity;
    return '$entity #$entityId';
  }

  factory WorkflowRequestDto.fromJson(Map<String, dynamic> json) =>
      WorkflowRequestDto(
        approvalId: (json['approval_id'] as num?)?.toInt() ?? 0,
        locationId: (json['location_id'] as num?)?.toInt(),
        module: (json['module'] ?? '').toString(),
        entityType: (json['entity_type'] ?? '').toString(),
        entityId: (json['entity_id'] as num?)?.toInt(),
        actionType: (json['action_type'] ?? '').toString(),
        title: (json['title'] ?? '').toString(),
        summary: json['summary'] as String?,
        requestReason: json['request_reason'] as String?,
        status: (json['status'] ?? '').toString(),
        priority: (json['priority'] ?? 'NORMAL').toString(),
        approverRoleId: (json['approver_role_id'] as num?)?.toInt() ?? 0,
        approverRoleName: json['approver_role_name'] as String?,
        payload: (json['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
        resultSnapshot:
            (json['result_snapshot'] as Map?)?.cast<String, dynamic>() ??
                const {},
        dueAt: DateTime.tryParse((json['due_at'] ?? '').toString()),
        isOverdue: (json['is_overdue'] as bool?) ?? false,
        escalationLevel: (json['escalation_level'] as num?)?.toInt() ?? 0,
        createdBy: (json['created_by'] as num?)?.toInt() ?? 0,
        createdByName: json['created_by_name'] as String?,
        updatedBy: (json['updated_by'] as num?)?.toInt(),
        approvedBy: (json['approved_by'] as num?)?.toInt(),
        approvedByName: json['approved_by_name'] as String?,
        approvedAt: DateTime.tryParse((json['approved_at'] ?? '').toString()),
        decisionReason: json['decision_reason'] as String?,
        createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
        updatedAt: DateTime.tryParse((json['updated_at'] ?? '').toString()),
        events: (json['events'] as List? ?? const [])
            .map((e) =>
                WorkflowRequestEventDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class WorkflowRepository {
  WorkflowRepository(this._dio);
  final Dio _dio;

  List<dynamic> _extractList(dynamic body) {
    if (body is List) return body;
    if (body is Map) {
      final data = body['data'];
      if (data is List) return data;
    }
    return const [];
  }

  Map<String, dynamic> _extractMap(dynamic body) {
    if (body is Map<String, dynamic>) {
      final data = body['data'];
      if (data is Map<String, dynamic>) return data;
      return body;
    }
    if (body is Map) return body.cast<String, dynamic>();
    return const {};
  }

  Future<List<WorkflowRequestDto>> listRequests({String? status}) async {
    final qp = <String, dynamic>{};
    if ((status ?? '').trim().isNotEmpty) {
      qp['status'] = status!.trim().toUpperCase();
    }
    final res = await _dio.get(
      '/workflow-requests',
      queryParameters: qp.isEmpty ? null : qp,
    );
    return _extractList(res.data)
        .map((e) => WorkflowRequestDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<WorkflowRequestDto> getRequest(int id) async {
    final res = await _dio.get('/workflow-requests/$id');
    return WorkflowRequestDto.fromJson(_extractMap(res.data));
  }

  Future<void> approve(int id, {String? remarks}) async {
    await _dio.put('/workflow-requests/$id/approve', data: {
      if (remarks != null && remarks.trim().isNotEmpty)
        'remarks': remarks.trim(),
    });
  }

  Future<void> reject(int id, {String? remarks}) async {
    await _dio.put('/workflow-requests/$id/reject', data: {
      if (remarks != null && remarks.trim().isNotEmpty)
        'remarks': remarks.trim(),
    });
  }
}

final workflowRepositoryProvider = Provider<WorkflowRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return WorkflowRepository(dio);
});
