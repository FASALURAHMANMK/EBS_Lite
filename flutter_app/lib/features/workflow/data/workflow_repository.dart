import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';

class WorkflowRequestDto {
  final int approvalId;
  final int stateId;
  final int approverRoleId;
  final String status;
  final String? remarks;
  final DateTime? approvedAt;
  final int createdBy;
  final int? updatedBy;

  const WorkflowRequestDto({
    required this.approvalId,
    required this.stateId,
    required this.approverRoleId,
    required this.status,
    required this.remarks,
    required this.approvedAt,
    required this.createdBy,
    required this.updatedBy,
  });

  factory WorkflowRequestDto.fromJson(Map<String, dynamic> json) =>
      WorkflowRequestDto(
        approvalId: (json['approval_id'] as num?)?.toInt() ?? 0,
        stateId: (json['state_id'] as num?)?.toInt() ?? 0,
        approverRoleId: (json['approver_role_id'] as num?)?.toInt() ?? 0,
        status: json['status'] as String? ?? '',
        remarks: json['remarks'] as String?,
        approvedAt: DateTime.tryParse(json['approved_at'] as String? ?? ''),
        createdBy: (json['created_by'] as num?)?.toInt() ?? 0,
        updatedBy: (json['updated_by'] as num?)?.toInt(),
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

  Future<List<WorkflowRequestDto>> listRequests() async {
    final res = await _dio.get('/workflow-requests');
    return _extractList(res.data)
        .map((e) => WorkflowRequestDto.fromJson(e as Map<String, dynamic>))
        .toList();
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
