import 'dart:io';

import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

bool _ffiInitialized = false;

sqflite.DatabaseFactory resolveDatabaseFactory() {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    if (!_ffiInitialized) {
      ffi.sqfliteFfiInit();
      _ffiInitialized = true;
    }
    return ffi.databaseFactoryFfi;
  }

  return sqflite.databaseFactory;
}
