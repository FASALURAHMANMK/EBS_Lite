class NotificationDto {
  final String key;
  final String type;
  final String title;
  final String body;
  final DateTime? createdAt;
  final bool isRead;

  NotificationDto({
    required this.key,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
  });

  factory NotificationDto.fromJson(Map<String, dynamic> json) {
    final created = json['created_at']?.toString();
    return NotificationDto(
      key: (json['key'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      createdAt: created == null ? null : DateTime.tryParse(created),
      isRead: (json['is_read'] as bool?) ?? false,
    );
  }
}
