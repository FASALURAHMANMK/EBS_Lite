import 'package:sqflite/sqflite.dart';

import 'outbox_db.dart';
import 'outbox_item.dart';

class OutboxStore {
  OutboxStore(this._db);

  final OutboxDb _db;

  Future<Database> _open() => _db.open();

  Future<int> enqueue(OutboxItem item) async {
    final db = await _open();
    return db.insert('outbox', item.toDb());
  }

  Future<int> countPending() async {
    final db = await _open();
    final res = await db.rawQuery(
        "SELECT COUNT(*) as c FROM outbox WHERE status IN ('queued','failed')");
    return (res.first['c'] as int?) ?? 0;
  }

  Future<OutboxItem?> nextPending({int maxAttempts = 5}) async {
    final db = await _open();
    final rows = await db.query(
      'outbox',
      where: "status IN ('queued','failed') AND attempts < ?",
      whereArgs: [maxAttempts],
      orderBy: 'created_at ASC, id ASC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return OutboxItem.fromDb(rows.first);
  }

  Future<void> markFailed(int id, String error) async {
    final db = await _open();
    await db.rawUpdate(
      'UPDATE outbox SET attempts = attempts + 1, status = ?, last_error = ? WHERE id = ?',
      ['failed', error, id],
    );
  }

  Future<void> markQueued(int id) async {
    final db = await _open();
    await db.rawUpdate(
      'UPDATE outbox SET status = ? WHERE id = ?',
      ['queued', id],
    );
  }

  Future<void> delete(int id) async {
    final db = await _open();
    await db.delete('outbox', where: 'id = ?', whereArgs: [id]);
  }
}
