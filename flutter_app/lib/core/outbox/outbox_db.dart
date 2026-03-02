import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

class OutboxDb {
  sqflite.Database? _db;

  Future<sqflite.Database> open() async {
    if (_db != null) return _db!;

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      ffi.sqfliteFfiInit();
      sqflite.databaseFactory = ffi.databaseFactoryFfi;
    }

    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'ebs_outbox.db');
    _db = await sqflite.openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE outbox (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL,
            method TEXT NOT NULL,
            path TEXT NOT NULL,
            query_params TEXT,
            headers TEXT,
            body TEXT,
            meta TEXT,
            idempotency_key TEXT,
            attempts INTEGER NOT NULL DEFAULT 0,
            status TEXT NOT NULL DEFAULT 'queued',
            created_at INTEGER NOT NULL,
            last_error TEXT
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_outbox_status_created ON outbox(status, created_at)');
      },
    );
    return _db!;
  }
}
