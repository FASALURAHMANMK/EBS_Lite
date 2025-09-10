import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'data/db.dart';
import 'data/sync_engine.dart';

// Configure your scope (single-tenant on client)
final scopeCompanyIdProvider = Provider<String>((_) => 'CMP001');
final scopeLocationIdProvider = Provider<String>((_) => 'LOC001');

final supabaseProvider = Provider<SupabaseClient>((_) => Supabase.instance.client);

final dbProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final db = ref.watch(dbProvider);
  final sb = ref.watch(supabaseProvider);
  final cmp = ref.watch(scopeCompanyIdProvider);
  final loc = ref.watch(scopeLocationIdProvider);
  final engine = SyncEngine(db: db, supabase: sb, companyId: cmp, locationId: loc);
  ref.onDispose(engine.dispose);
  return engine;
});