import 'package:drift/drift.dart';

class SyncMeta extends Table {
  TextColumn get scopeCompanyId => text()();
  TextColumn get scopeLocationId => text()();
  // renamed from tableName → tblName to avoid colliding with Table.tableName
  TextColumn get tblName => text()();
  DateTimeColumn get lastServerUpdatedAt => dateTime().nullable()();
  DateTimeColumn get lastLocalPushedAt => dateTime().nullable()();
  @override
  Set<Column<Object>> get primaryKey => {
    scopeCompanyId,
    scopeLocationId,
    tblName,
  };
}

class Outbox extends Table {
  TextColumn get id => text()();
  TextColumn get tblName => text()();
  TextColumn get op => text()();
  TextColumn get payloadJson => text()();

  // NEW: store the target row's primary key for safe lookups
  TextColumn get rowId => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Products extends Table {
  TextColumn get id => text()();
  TextColumn get companyId => text()();
  TextColumn get locationId => text().nullable()();
  TextColumn get code => text()();
  TextColumn get name => text()();
  RealColumn get price => real().withDefault(const Constant(0))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Sales extends Table {
  TextColumn get id => text()();
  TextColumn get companyId => text()();
  TextColumn get locationId => text()();
  DateTimeColumn get txnDate => dateTime()();
  RealColumn get total => real()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}
