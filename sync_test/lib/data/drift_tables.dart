import 'package:drift/drift.dart';

class SyncMeta extends Table {
  TextColumn get scopeCompanyId => text()();
  TextColumn get scopeLocationId => text()();
  TextColumn get tableName => text()();
  DateTimeColumn get lastServerUpdatedAt => dateTime().nullable()();
  DateTimeColumn get lastLocalPushedAt => dateTime().nullable()();
  @override
  Set<Column<Object>> get primaryKey => {scopeCompanyId, scopeLocationId, tableName};
}

class Outbox extends Table {
  TextColumn get id => text()();
  TextColumn get tableName => text()();
  TextColumn get op => text()();
  TextColumn get payloadJson => text()();
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