import 'package:drift/drift.dart';
import '../db.dart';
import '../../utils/json.dart';
import 'package:uuid/uuid.dart';

final _uuid = const Uuid();

abstract class OutboxableRepo<T> {
  AppDatabase get db;
  String get tableName; // server table name

  Map<String, Object?> toServerJson(T row);
  Future<void> upsertLocal(T row);

  Future<void> queueUpsert(T row) async {
    // Every repo’s toServerJson(row) MUST include the 'id'
    final data = toServerJson(row);
    final rowId = (data['id'] as String?) ?? '';

    await db
        .into(db.outbox)
        .insert(
          OutboxCompanion.insert(
            id: _uuid.v4(),
            tblName: tableName,
            op: 'upsert',
            payloadJson: encodeJson(data),
            rowId: rowId.isEmpty
                ? const Value.absent()
                : Value(rowId), // ← set rowId
          ),
        );
  }

  Future<void> queueDelete(String id) async {
    await db
        .into(db.outbox)
        .insert(
          OutboxCompanion.insert(
            id: _uuid.v4(),
            tblName: tableName,
            op: 'delete',
            payloadJson: encodeJson({'id': id}),
            rowId: Value(id), // ← set rowId
          ),
        );
  }
}
