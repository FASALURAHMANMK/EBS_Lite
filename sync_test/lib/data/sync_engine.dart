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
  SyncEngine({
    required this.db,
    required this.supabase,
    required this.companyId,
    required this.locationId,
  });

  final _logCtrl = StreamController<String>.broadcast();
  Stream<String> get logStream => _logCtrl.stream;
  void _log(String s) =>
      _logCtrl.add('[${DateTime.now().toIso8601String()}] $s');

  RealtimeChannel? _prodChan;
  RealtimeChannel? _saleChan;
  bool _running = false;
  Timer? _pullTimer;
  Timer? _pushTimer;
  Timer? _flushDebounce;
  StreamSubscription<List<OutboxData>>? _outboxSub;

  Future<void> start() async {
    if (_running) return;
    _running = true;
    _log('Starting sync…');
    await _ensureBootstrap();
    _subscribeRealtime();
    _subscribeOutbox();
    _scheduleLoops();
    // Kick off immediate catch-up and push for snappier UX
    await _catchUp();
    await _flushOutbox();
  }

  Future<void> stop() async {
    _running = false;
    _log('Stopping sync…');
    await _prodChan?.unsubscribe();
    await _saleChan?.unsubscribe();
    await _outboxSub?.cancel();
    _pullTimer?.cancel();
    _pushTimer?.cancel();
    _flushDebounce?.cancel();
  }

  void dispose() {
    _logCtrl.close();
  }

  Future<void> _ensureBootstrap() async {
    final metas = await db.select(db.syncMeta).get();
    if (metas.isNotEmpty) {
      _log('Cursors present. Skipping bootstrap.');
      return;
    }
    _log('Bootstrap: pulling masters (products)…');
    await _pagedPullProducts();
    _log('Bootstrap: pulling transactions (sales last 30d)…');
    await _pagedPullSales();
    await _initCursors();
  }

  Future<void> _initCursors() async {
    // Typed aggregate for products
    final proRow = await (db.selectOnly(
      db.products,
    )..addColumns([db.products.updatedAt.max()])).getSingle();
    final DateTime? proMax = proRow.read(db.products.updatedAt.max());

    // Typed aggregate for sales
    final salRow = await (db.selectOnly(
      db.sales,
    )..addColumns([db.sales.updatedAt.max()])).getSingle();
    final DateTime? salMax = salRow.read(db.sales.updatedAt.max());

    await db
        .into(db.syncMeta)
        .insertOnConflictUpdate(
          SyncMetaCompanion.insert(
            scopeCompanyId: companyId,
            scopeLocationId: locationId,
            tblName: 'products',
            lastServerUpdatedAt: Value(proMax),
            lastLocalPushedAt: const Value.absent(),
          ),
        );

    await db
        .into(db.syncMeta)
        .insertOnConflictUpdate(
          SyncMetaCompanion.insert(
            scopeCompanyId: companyId,
            scopeLocationId: locationId,
            tblName: 'sales',
            lastServerUpdatedAt: Value(salMax),
            lastLocalPushedAt: const Value.absent(),
          ),
        );

    _log('Cursors initialized.');
  }

  void _subscribeRealtime() {
    _prodChan = supabase.channel('realtime:products')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'products',
        callback: (payload) async {
          final row = payload.newRecord ?? payload.oldRecord ?? {};
          await _applyProduct(row);
          _log('Realtime products ${payload.eventType.name}: ${row['id']}');
        },
      )
      ..subscribe();

    _saleChan = supabase.channel('realtime:sales')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'sales',
        callback: (payload) async {
          final row = payload.newRecord ?? payload.oldRecord ?? {};
          await _applySale(row);
          _log('Realtime sales ${payload.eventType.name}: ${row['id']}');
        },
      )
      ..subscribe();

    _log('Realtime subscriptions active.');
  }

  void _scheduleLoops() {
    _pullTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_running) await _catchUp();
    });
    _pushTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_running) await _flushOutbox();
    });
  }

  void _subscribeOutbox() {
    _outboxSub?.cancel();
    _outboxSub = (db.select(db.outbox).watch()).listen((rows) {
      if (!_running) return;
      final now = DateTime.now();
      final hasReady = rows.any((r) => r.nextAttemptAt == null || (r.nextAttemptAt != null && r.nextAttemptAt!.isBefore(now)));
      if (hasReady) {
        _flushDebounce?.cancel();
        _flushDebounce = Timer(const Duration(milliseconds: 200), () {
          if (_running) {
            _flushOutbox();
          }
        });
      }
    });
  }

  Future<void> _pagedPullProducts() async {
    const pageSize = 1000;
    int from = 0;
    final since = DateTime.fromMillisecondsSinceEpoch(0).toUtc().toIso8601String();
    while (true) {
      try {
        final res = await supabase.functions.invoke(
          'sync-pull',
          body: {
            'table': 'products',
            'company_id': companyId,
            'location_id': locationId,
            'since': since,
            'use_gt': false,
            'from': from,
            'limit': pageSize,
          },
        );
        if (res.status != 200) {
          _log('Bootstrap products pull failed: ${res.status}, data: ${res.data}');
          break;
        }
        final rows = (res.data as List).cast<Map<String, dynamic>>();
        if (rows.isEmpty) break;
        await db.transaction(() async {
          for (final r in rows) {
            await _applyProduct(r);
          }
        });
        if (rows.length < pageSize) break;
        from += pageSize;
      } catch (e) {
        _log('Bootstrap products pull error: $e');
        break;
      }
    }
  }

  Future<void> _pagedPullSales() async {
    const pageSize = 1000;
    int from = 0;
    final since = DateTime.fromMillisecondsSinceEpoch(0).toUtc().toIso8601String();
    while (true) {
      try {
        final res = await supabase.functions.invoke(
          'sync-pull',
          body: {
            'table': 'sales',
            'company_id': companyId,
            'location_id': locationId,
            'since': since,
            'use_gt': false,
            'from': from,
            'limit': pageSize,
            'days': 30,
          },
        );
        if (res.status != 200) {
          _log('Bootstrap sales pull failed: ${res.status}, data: ${res.data}');
          break;
        }
        final rows = (res.data as List).cast<Map<String, dynamic>>();
        if (rows.isEmpty) break;
        await db.transaction(() async {
          for (final r in rows) {
            await _applySale(r);
          }
        });
        if (rows.length < pageSize) break;
        from += pageSize;
      } catch (e) {
        _log('Bootstrap sales pull error: $e');
        break;
      }
    }
  }

  Future<void> _catchUp() async {
    _log('Catch-up pull…');
    await _pullDelta('products');
    await _pullDelta('sales');
    await _purgeOldTransactions();
  }

  Future<void> _pullDelta(String table) async {
    final meta =
        await (db.select(db.syncMeta)..where(
              (m) =>
                  m.scopeCompanyId.equals(companyId) &
                  m.scopeLocationId.equals(locationId) &
                  m.tblName.equals(table),
            ))
            .getSingle();
    final since =
        meta.lastServerUpdatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    List<Map<String, dynamic>> rows = const [];
    try {
      final res = await supabase.functions.invoke(
        'sync-pull',
        body: {
          'table': table,
          'company_id': companyId,
          'location_id': locationId,
          'since': since.toIso8601String(),
          'use_gt': meta.lastServerUpdatedAt != null,
          'from': 0,
          'limit': 1000,
          'days': 30,
        },
      );
      if (res.status != 200) {
        _log('Delta pull failed for $table: ${res.status}, data: ${res.data}');
        return;
      }
      rows = (res.data as List).cast<Map<String, dynamic>>();
    } catch (e) {
      _log('Delta pull exception for $table: $e');
      return;
    }

    if (rows.isEmpty) return;
    await db.transaction(() async {
      DateTime? maxTs;
      for (final r in rows) {
        final ts = DateTime.parse((r['updated_at'] as String));
        maxTs = (maxTs == null) ? ts : (ts.isAfter(maxTs!) ? ts : maxTs);
        if (table == 'products') {
          await _applyProduct(r);
        } else {
          await _applySale(r);
        }
      }
      await (db.update(db.syncMeta)..where(
            (m) =>
                m.scopeCompanyId.equals(companyId) &
                m.scopeLocationId.equals(locationId) &
                m.tblName.equals(table),
          ))
          .write(SyncMetaCompanion(lastServerUpdatedAt: Value(maxTs!)));
    });
    _log('Pulled ${rows.length} from $table.');
  }

  Future<void> _applyProduct(Map<String, dynamic> r) async {
    if (r.isEmpty) return;
    final del = (r['deleted'] as bool?) ?? false;
    await db
        .into(db.products)
        .insertOnConflictUpdate(
          ProductsCompanion.insert(
            id: r['id'] as String,
            companyId: r['company_id'] as String,
            locationId: Value(r['location_id'] as String?),
            code: r['code'] as String,
            name: r['name'] as String,
            price: Value(((r['price'] as num?) ?? 0).toDouble()),
            deleted: Value(del),
            updatedAt: DateTime.parse(r['updated_at'] as String),
          ),
        );
  }

  Future<void> _applySale(Map<String, dynamic> r) async {
    if (r.isEmpty) return;
    final del = (r['deleted'] as bool?) ?? false;
    await db
        .into(db.sales)
        .insertOnConflictUpdate(
          SalesCompanion.insert(
            id: r['id'] as String,
            companyId: r['company_id'] as String,
            locationId: r['location_id'] as String,
            txnDate: DateTime.parse(r['txn_date'] as String),
            total: ((r['total'] as num?) ?? 0).toDouble(),
            deleted: Value(del),
            updatedAt: DateTime.parse(r['updated_at'] as String),
          ),
        );
  }

  Future<void> _flushOutbox() async {
    final now = DateTime.now();
    final items =
        await (db.select(db.outbox)
              ..where(
                (o) =>
                    o.nextAttemptAt.isNull() |
                    o.nextAttemptAt.isSmallerOrEqualValue(now),
              )
              ..orderBy([(o) => OrderingTerm.asc(o.createdAt)])
              ..limit(100))
            .get();
    if (items.isEmpty) return;

    final payload = items
        .map(
          (e) => {
            'id': e.id,
            'table': e.tblName,
            'op': e.op,
            'row': decodeJson<Map<String, Object?>>(e.payloadJson),
          },
        )
        .toList();

    try {
      final res = await supabase.functions.invoke(
        'sync-apply',
        body: {
          'items': payload,
          'company_id': companyId,
          'location_id': locationId,
        },
      );
      if (res.status == 200) {
        await db.transaction(() async {
          for (final it in items) {
            await (db.delete(db.outbox)..where((o) => o.id.equals(it.id))).go();
          }
        });
        _log('Pushed ${items.length} outbox items.');
        // Pull immediately after push to reflect server-side changes
        await _catchUp();
      } else {
        await _backoff(items);
        _log('Push failed status ${res.status}, data: ${res.data}');
      }
    } catch (e) {
      await _backoff(items);
      _log('Push exception: $e');
    }
  }

  Future<void> _backoff(List<OutboxData> items) async {
    final next = DateTime.now().add(
      Duration(minutes: min(10, 1 + (items.first.attempts))),
    );
    await db.transaction(() async {
      for (final it in items) {
        await (db.update(db.outbox)..where((o) => o.id.equals(it.id))).write(
          OutboxCompanion(
            attempts: Value(it.attempts + 1),
            nextAttemptAt: Value(next),
          ),
        );
      }
    });
  }

  Future<void> _purgeOldTransactions() async {
    final cutoff = DateTime.now().subtract(const Duration(days: 31));

    // read all pending sales IDs in outbox (won’t purge those)
    final pending = await (db.select(
      db.outbox,
    )..where((o) => o.tblName.equals('sales') & o.rowId.isNotNull())).get();
    final pendingIds = pending.map((e) => e.rowId).whereType<String>().toList();

    if (pendingIds.isEmpty) {
      await (db.delete(
        db.sales,
      )..where((s) => s.txnDate.isSmallerThanValue(cutoff))).go();
    } else {
      await (db.delete(db.sales)..where(
            (s) =>
                s.txnDate.isSmallerThanValue(cutoff) & s.id.isNotIn(pendingIds),
          ))
          .go();
    }

    _log('Purged transactions older than 31 days.');
  }
}
