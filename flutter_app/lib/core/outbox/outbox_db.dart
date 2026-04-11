import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../sqflite_factory.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

class OutboxDb {
  sqflite.Database? _db;

  static const int _currentVersion = 2;

  Future<sqflite.Database> open() async {
    if (_db != null) return _db!;

    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'ebs_outbox.db');
    final factory = resolveDatabaseFactory();
    _db = await factory.openDatabase(
      path,
      options: sqflite.OpenDatabaseOptions(
        version: _currentVersion,
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
          await db.execute(
              'CREATE UNIQUE INDEX idx_outbox_idempotency_key ON outbox(idempotency_key)');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            // Migration v2: add unique index on idempotency_key to prevent
            // duplicate outbox entries for the same idempotent operation.
            // SQLite allows multiple NULLs in a UNIQUE column, which is
            // desirable since not all outbox items carry an idempotency key.
            await db.execute(
                'CREATE UNIQUE INDEX idx_outbox_idempotency_key ON outbox(idempotency_key)');
          }
        },
      ),
    );
    return _db!;
  }
}
