import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app_providers.dart';
import '../db.dart';
import '../sync_engine.dart';
import '../../utils/json.dart';
import 'package:uuid/uuid.dart';

final _uuid = const Uuid();

abstract class OutboxableRepo<T> {
  AppDatabase get db;
  String get tableName;
  Map<String, Object?> toServerJson(T row);

  Future<void> upsertLocal(T row);

  Future<void> queueUpsert(T row) async {
    await db.into(db.outbox).insert(OnConflictInsert(db, tableName, 'upsert', toServerJson(row)));
  }

  Future<void> queueDelete(String id) async {
    await db.into(db.outbox).insert(OutboxCompanion.insert(
      id: _uuid.v4(), tableName: tableName, op: 'delete', payloadJson: encodeJson({'id': id}),
    ));
  }
}

class OnConflictInsert extends OutboxCompanion {
  OnConflictInsert(AppDatabase db, String table, String op, Map<String, Object?> payload)
      : super.insert(
          id: _uuid.v4(),
          tableName: table,
          op: op,
          payloadJson: encodeJson(payload),
        );
}