import 'dart:async';
import 'dart:math';
import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'db.dart';
import '../utils/json.dart';

class SyncEngine {
  final AppDatabase db;
  final SupabaseClient supabase;
  final String companyId;
  final String locationId;
  SyncEngine({required this.db, required this.supabase, required this.companyId, required this.locationId});

  final _logCtrl = StreamController<String>.broadcast();
  Stream<String> get logStream => _logCtrl.stream;
  void _log(String s) => _logCtrl.add('[${DateTime.now().toIso8601String()}] $s');

  RealtimeChannel? _prodChan;
  RealtimeChannel? _saleChan;
  bool _running = false;
  Timer? _pullTimer;
  Timer? _pushTimer;

  Future<void> start() async {
    if (_running) return; _running = true; _log('Starting sync…');
    await _ensureBootstrap();
    _subscribeRealtime();
    _scheduleLoops();
  }

  Future<void> stop() async {
    _running = false; _log('Stopping sync…');
    await _prodChan?.unsubscribe();
    await _saleChan?.unsubscribe();
    _pullTimer?.cancel();
    _pushTimer?.cancel();
  }

  void dispose() { _logCtrl.close(); }

  Future<void> _ensureBootstrap() async {
    final metas = await db.select(db.syncMeta).get();
    if (metas.isNotEmpty) { _log('Cursors present. Skipping bootstrap.'); return; }
    _log('Bootstrap: pulling masters (products)…');
    await _pagedPullProducts();
    _log('Bootstrap: pulling transactions (sales last 30d)…');
    await _pagedPullSales();
    await _initCursors();
  }

  Future<void> _initCursors() async {
    final proMax = await db.customSelect('SELECT max(updated_at) m FROM products').getSingle();
    final salMax = await db.customSelect('SELECT max(updated_at) m FROM sales').getSingle();
    await db.into(db.syncMeta).insertOnConflictUpdate(SyncMetaCompanion.insert(
      scopeCompanyId: companyId,
      scopeLocationId: locationId,
      tableName: 'products',
      lastServerUpdatedAt: Value(proMax.data['m'] as DateTime?),
      lastLocalPushedAt: const Value.absent(),
    ));
    await db.into(db.syncMeta).insertOnConflictUpdate(SyncMetaCompanion.insert(
      scopeCompanyId: companyId,
      scopeLocationId: locationId,
      tableName: 'sales',
      lastServerUpdatedAt: Value(salMax.data['m'] as DateTime?),
      lastLocalPushedAt: const Value.absent(),
    ));
    _log('Cursors initialized.');
  }

  void _subscribeRealtime() {
    _prodChan = supabase.channel('realtime:products')
      ..onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'products', callback: (payload) async {
        final row = payload.newRecord ?? payload.oldRecord ?? {}; await _applyProduct(row);
        _log('Realtime products ${payload.eventType.name}: ${row['id']}');
      })
      ..subscribe();

    _saleChan = supabase.channel('realtime:sales')
      ..onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'sales', callback: (payload) async {
        final row = payload.newRecord ?? payload.oldRecord ?? {}; await _applySale(row);
        _log('Realtime sales ${payload.eventType.name}: ${row['id']}');
      })
      ..subscribe();

    _log('Realtime subscriptions active.');
  }

  void _scheduleLoops() {
    _pullTimer = Timer.periodic(const Duration(seconds: 25), (_) async { if (_running) await _catchUp(); });
    _pushTimer = Timer.periodic(const Duration(seconds: 20), (_) async { if (_running) await _flushOutbox(); });
  }

  Future<void> _pagedPullProducts() async {
    const pageSize = 1000; int from = 0; while (true) {
      final q = supabase.from('products').select().order('updated_at', ascending: true)
        .eq('company_id', companyId)
        .or('location_id.is.null,location_id.eq.$locationId')
        .range(from, from + pageSize - 1);
      final rows = await q as List<dynamic>;
      if (rows.isEmpty) break; await db.transaction(() async { for (final r in rows.cast<Map<String, dynamic>>()) { await _applyProduct(r); } });
      if (rows.length < pageSize) break; from += pageSize;
    }
  }

  Future<void> _pagedPullSales() async {
    const pageSize = 1000; int from = 0; final since = DateTime.now().subtract(const Duration(days: 30));
    while (true) {
      final q = supabase.from('sales').select().order('updated_at', ascending: true)
        .eq('company_id', companyId).eq('location_id', locationId)
        .gte('txn_date', since.toIso8601String()).range(from, from + pageSize - 1);
      final rows = await q as List<dynamic>;
      if (rows.isEmpty) break; await db.transaction(() async { for (final r in rows.cast<Map<String, dynamic>>()) { await _applySale(r); } });
      if (rows.length < pageSize) break; from += pageSize;
    }
  }

  Future<void> _catchUp() async {
    _log('Catch-up pull…');
    await _pullDelta('products');
    await _pullDelta('sales');
    await _purgeOldTransactions();
  }

  Future<void> _pullDelta(String table) async {
    final meta = await (db.select(db.syncMeta)
          ..where((m) => m.scopeCompanyId.equals(companyId) & m.scopeLocationId.equals(locationId) & m.tableName.equals(table)))
        .getSingle();
    final since = meta.lastServerUpdatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final base = supabase.from(table).select().gte('updated_at', since.toIso8601String()).order('updated_at', ascending: true).eq('company_id', companyId);
    if (table == 'products') {
      base.or('location_id.is.null,location_id.eq.$locationId');
    } else {
      base.eq('location_id', locationId).gte('txn_date', DateTime.now().subtract(const Duration(days: 30)).toIso8601String());
    }
    final rows = await base as List<dynamic>;
    if (rows.isEmpty) return;
    await db.transaction(() async {
      late DateTime maxTs;
      for (final r in rows.cast<Map<String, dynamic>>()) {
        final ts = DateTime.parse((r['updated_at'] as String));
        maxTs = (maxTs == null) ? ts : (ts.isAfter(maxTs) ? ts : maxTs);
        if (table == 'products') { await _applyProduct(r); } else { await _applySale(r); }
      }
      await (db.update(db.syncMeta)
            ..where((m) => m.scopeCompanyId.equals(companyId) & m.scopeLocationId.equals(locationId) & m.tableName.equals(table)))
          .write(SyncMetaCompanion(lastServerUpdatedAt: Value(maxTs)));
    });
    _log('Pulled ${rows.length} from $table.');
  }

  Future<void> _applyProduct(Map<String, dynamic> r) async {
    if (r.isEmpty) return;
    final del = (r['deleted'] as bool?) ?? false;
    await db.into(db.products).insertOnConflictUpdate(ProductsCompanion.insert(
      id: r['id'] as String,
      companyId: r['company_id'] as String,
      locationId: Value(r['location_id'] as String?),
      code: r['code'] as String,
      name: r['name'] as String,
      price: Value(((r['price'] as num?) ?? 0).toDouble()),
      deleted: Value(del),
      updatedAt: DateTime.parse(r['updated_at'] as String),
    ));
  }

  Future<void> _applySale(Map<String, dynamic> r) async {
    if (r.isEmpty) return;
    final del = (r['deleted'] as bool?) ?? false;
    await db.into(db.sales).insertOnConflictUpdate(SalesCompanion.insert(
      id: r['id'] as String,
      companyId: r['company_id'] as String,
      locationId: r['location_id'] as String,
      txnDate: DateTime.parse(r['txn_date'] as String),
      total: ((r['total'] as num?) ?? 0).toDouble(),
      deleted: Value(del),
      updatedAt: DateTime.parse(r['updated_at'] as String),
    ));
  }

  Future<void> _flushOutbox() async {
    final now = DateTime.now();
    final items = await (db.select(db.outbox)
          ..where((o) => o.nextAttemptAt.isNull() | o.nextAttemptAt.isSmallerOrEqualValue(now))
          ..orderBy([(o) => OrderingTerm.asc(o.createdAt)])
          ..limit(100))
        .get();
    if (items.isEmpty) return;

    final payload = items
        .map((e) => {'id': e.id, 'table': e.tableName, 'op': e.op, 'row': decodeJson<Map<String, Object?>>(e.payloadJson)})
        .toList();

    try {
      final res = await supabase.functions.invoke('sync-apply', body: {
        'items': payload,
        'company_id': companyId,
        'location_id': locationId,
      });
      if (res.status == 200) {
        await db.transaction(() async {
          for (final it in items) {
            await (db.delete(db.outbox)..where((o) => o.id.equals(it.id))).go();
          }
        });
        _log('Pushed ${items.length} outbox items.');
      } else {
        await _backoff(items);
        _log('Push failed status ${res.status}.');
      }
    } catch (e) {
      await _backoff(items);
      _log('Push exception: $e');
    }
  }

  Future<void> _backoff(List<OutboxData> items) async {
    final next = DateTime.now().add(Duration(minutes: min(10, 1 + (items.first.attempts))));
    await db.transaction(() async {
      for (final it in items) {
        await (db.update(db.outbox)..where((o) => o.id.equals(it.id))).write(OutboxCompanion(
          attempts: Value(it.attempts + 1), nextAttemptAt: Value(next),
        ));
      }
    });
  }

  Future<void> _purgeOldTransactions() async {
    final cutoff = DateTime.now().subtract(const Duration(days: 31));
    await db.customUpdate('DELETE FROM sales WHERE txn_date < ? AND id NOT IN (SELECT json_extract(payloadJson, "$.id") FROM outbox WHERE tableName = "sales")',
        variables: [Variable<DateTime>(cutoff)], updates: {db.sales});
    _log('Purged transactions older than 31 days.');
  }
}