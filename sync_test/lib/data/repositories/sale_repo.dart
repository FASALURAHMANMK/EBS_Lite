import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../app_providers.dart';
import '../db.dart';
import 'generic_repo.dart';

final saleRepoProvider = Provider<SaleRepo>(
  (ref) => SaleRepo(
    ref.read(dbProvider),
    ref.read(scopeCompanyIdProvider),
    ref.read(scopeLocationIdProvider),
  ),
);

class SaleRepo extends OutboxableRepo<SalesCompanion> {
  SaleRepo(this.db, this.companyId, this.locationId);
  @override
  final AppDatabase db;
  final String companyId;
  final String locationId;
  @override
  String get tableName => 'sales';

  @override
  Map<String, Object?> toServerJson(SalesCompanion row) => {
    'id': row.id.value,
    'company_id': row.companyId.value,
    'location_id': row.locationId.value,
    'txn_date': row.txnDate.value.toUtc().toIso8601String(),
    'total': row.total.value,
    'deleted': row.deleted.present ? row.deleted.value : false,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };

  @override
  Future<void> upsertLocal(SalesCompanion row) async {
    await db.into(db.sales).insertOnConflictUpdate(row);
  }

  Future<void> seedSamples() async {
    for (var i = 0; i < 3; i++) {
      final id = const Uuid().v4();
      final row = SalesCompanion.insert(
        id: id,
        companyId: companyId,
        locationId: locationId,
        txnDate: DateTime.now().subtract(Duration(days: i)),
        total: (10 + i).toDouble(),
        deleted: const Value(false),
        updatedAt: DateTime.now(),
      );
      await upsertLocal(row);
      await queueUpsert(row);
    }
  }
}
