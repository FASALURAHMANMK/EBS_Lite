class NotificationDto {
  final String key;
  final String type;
  final String title;
  final String body;
  final String status;
  final String severity;
  final DateTime? createdAt;
  final DateTime? dueAt;
  final bool isRead;
  final bool isOverdue;
  final int? approvalId;
  final String? entityType;
  final int? entityId;
  final int? locationId;
  final int? productId;
  final String? actionLabel;
  final String? badgeLabel;

  const NotificationDto({
    required this.key,
    required this.type,
    required this.title,
    required this.body,
    required this.status,
    required this.severity,
    required this.createdAt,
    required this.dueAt,
    required this.isRead,
    required this.isOverdue,
    required this.approvalId,
    required this.entityType,
    required this.entityId,
    required this.locationId,
    required this.productId,
    required this.actionLabel,
    required this.badgeLabel,
  });

  factory NotificationDto.fromJson(Map<String, dynamic> json) {
    final created = json['created_at']?.toString();
    final due = json['due_at']?.toString();
    return NotificationDto(
      key: (json['key'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      severity: (json['severity'] ?? '').toString(),
      createdAt: created == null ? null : DateTime.tryParse(created),
      dueAt: due == null ? null : DateTime.tryParse(due),
      isRead: (json['is_read'] as bool?) ?? false,
      isOverdue: (json['is_overdue'] as bool?) ?? false,
      approvalId: (json['approval_id'] as num?)?.toInt(),
      entityType: json['entity_type'] as String?,
      entityId: (json['entity_id'] as num?)?.toInt(),
      locationId: (json['location_id'] as num?)?.toInt(),
      productId: (json['product_id'] as num?)?.toInt(),
      actionLabel: json['action_label'] as String?,
      badgeLabel: json['badge_label'] as String?,
    );
  }
}
