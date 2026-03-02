import 'dart:convert';

class OutboxItem {
  OutboxItem({
    this.id,
    required this.type,
    required this.method,
    required this.path,
    this.queryParams,
    this.headers,
    this.body,
    this.meta,
    this.idempotencyKey,
    this.attempts = 0,
    this.status = 'queued',
    int? createdAt,
    this.lastError,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  final int? id;
  final String type;
  final String method;
  final String path;
  final Map<String, dynamic>? queryParams;
  final Map<String, dynamic>? headers;
  final Map<String, dynamic>? body;
  final Map<String, dynamic>? meta;
  final String? idempotencyKey;
  final int attempts;
  final String status; // queued | failed
  final int createdAt;
  final String? lastError;

  OutboxItem copyWith({
    int? id,
    int? attempts,
    String? status,
    String? lastError,
  }) {
    return OutboxItem(
      id: id ?? this.id,
      type: type,
      method: method,
      path: path,
      queryParams: queryParams,
      headers: headers,
      body: body,
      meta: meta,
      idempotencyKey: idempotencyKey,
      attempts: attempts ?? this.attempts,
      status: status ?? this.status,
      createdAt: createdAt,
      lastError: lastError ?? this.lastError,
    );
  }

  Map<String, dynamic> toDb() => {
        if (id != null) 'id': id,
        'type': type,
        'method': method,
        'path': path,
        'query_params': _encode(queryParams),
        'headers': _encode(headers),
        'body': _encode(body),
        'meta': _encode(meta),
        'idempotency_key': idempotencyKey,
        'attempts': attempts,
        'status': status,
        'created_at': createdAt,
        'last_error': lastError,
      };

  factory OutboxItem.fromDb(Map<String, dynamic> row) => OutboxItem(
        id: row['id'] as int?,
        type: row['type'] as String? ?? '',
        method: row['method'] as String? ?? 'POST',
        path: row['path'] as String? ?? '',
        queryParams: _decode(row['query_params']),
        headers: _decode(row['headers']),
        body: _decode(row['body']),
        meta: _decode(row['meta']),
        idempotencyKey: row['idempotency_key'] as String?,
        attempts: (row['attempts'] as int?) ?? 0,
        status: row['status'] as String? ?? 'queued',
        createdAt: (row['created_at'] as int?) ??
            DateTime.now().millisecondsSinceEpoch,
        lastError: row['last_error'] as String?,
      );

  static String? _encode(Map<String, dynamic>? value) {
    if (value == null) return null;
    return jsonEncode(value);
  }

  static Map<String, dynamic>? _decode(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return null;
  }
}
