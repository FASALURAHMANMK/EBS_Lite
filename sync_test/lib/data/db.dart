import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'drift_tables.dart';
part 'db.g.dart';

@DriftDatabase(tables: [SyncMeta, Outbox, Products, Sales])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open());
  @override
  int get schemaVersion => 1;
}

LazyDatabase _open() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    if (kDebugMode) {
      print('DB Path: ${dir.path}');
    }
    final file = File(p.join(dir.path, 'sync_test.sqlite'));
    // NativeDatabase.createInBackground is valid
    return NativeDatabase.createInBackground(file);
  });
}
