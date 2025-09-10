import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../app_providers.dart';
import '../db.dart';
import 'generic_repo.dart';

final productRepoProvider = Provider<ProductRepo>((ref) => ProductRepo(ref.read(dbProvider), ref.read(scopeCompanyIdProvider), ref.read(scopeLocationIdProvider)));

class ProductRepo extends OutboxableRepo<ProductsCompanion> {
  ProductRepo(this.db, this.companyId, this.locationId);
  @override
  final AppDatabase db;
  final String companyId;
  final String locationId;
  @override
  String get tableName => 'products';

  @override
  Map<String, Object?> toServerJson(ProductsCompanion row) => {
        'id': row.id.value,
        'company_id': row.companyId.value,
        'location_id': row.locationId.present ? row.locationId.value : null,
        'code': row.code.value,
        'name': row.name.value,
        'price': row.price.present ? row.price.value : 0,
        'deleted': row.deleted.present ? row.deleted.value : false,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

  @override
  Future<void> upsertLocal(ProductsCompanion row) async {
    await db.into(db.products).insertOnConflictUpdate(row);
  }

  Future<void> insertRandom() async {
    final id = const Uuid().v4();
    final row = ProductsCompanion.insert(
      id: id,
      companyId: companyId,
      locationId: const Value(null),
      code: 'P-${id.substring(0,6)}',
      name: 'Local Item ${DateTime.now().millisecondsSinceEpoch}',
      price: const Value(1.0),
      deleted: const Value(false),
      updatedAt: DateTime.now(),
    );
    await upsertLocal(row);
    await queueUpsert(row);
  }

  Future<void> seedSamples() async {
    for (var i = 0; i < 5; i++) {
      await insertRandom();
    }
  }
}