import 'dart:convert';

import 'package:sqflite/sqflite.dart' as sqflite;

import 'cache_db.dart';

class CacheStore {
  CacheStore(this._db);
  final CacheDb _db;

  Future<sqflite.Database> _open() => _db.open();

  Future<void> setMeta(String key, String value) async {
    final db = await _open();
    await db.insert(
      'cache_meta',
      {'key': key, 'value': value},
      conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
    );
  }

  Future<String?> getMeta(String key) async {
    final db = await _open();
    final rows = await db.query('cache_meta',
        where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> upsertProducts({
    required int locationId,
    required List<Map<String, dynamic>> items,
  }) async {
    final db = await _open();
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final batch = db.batch();
    for (final p in items) {
      final id = (p['product_id'] as num?)?.toInt() ?? 0;
      if (id <= 0) continue;
      final name = (p['name'] as String? ?? '').trim();
      final barcode = (p['barcode'] as String?)?.trim();
      final category = (p['category_name'] as String?)?.trim();
      final search = _searchText([name, barcode, category]);
      batch.insert(
        'cache_products',
        {
          'location_id': locationId,
          'product_id': id,
          'name': name,
          'barcode': barcode,
          'search_text': search,
          'raw_json': jsonEncode(p),
          'updated_at_ms': now,
        },
        conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<int> countProducts({required int locationId}) async {
    final db = await _open();
    final rows = await db.rawQuery(
      'SELECT COUNT(*) as c FROM cache_products WHERE location_id = ?',
      [locationId],
    );
    if (rows.isEmpty) return 0;
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<List<Map<String, dynamic>>> searchProducts({
    required int locationId,
    required String query,
    int limit = 50,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final db = await _open();
    final like = '%${q.toLowerCase()}%';
    final rows = await db.query(
      'cache_products',
      columns: const ['raw_json'],
      where: 'location_id = ? AND search_text LIKE ?',
      whereArgs: [locationId, like],
      limit: limit,
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows
        .map((r) => jsonDecode(r['raw_json'] as String) as Map<String, dynamic>)
        .toList();
  }

  Future<void> upsertCustomers(List<Map<String, dynamic>> items) async {
    final db = await _open();
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final batch = db.batch();
    for (final c in items) {
      final id = (c['customer_id'] as num?)?.toInt() ?? 0;
      if (id <= 0) continue;
      final name = (c['name'] as String? ?? '').trim();
      final phone = (c['phone'] as String?)?.trim();
      final email = (c['email'] as String?)?.trim();
      final search = _searchText([name, phone, email]);
      batch.insert(
        'cache_customers',
        {
          'customer_id': id,
          'name': name,
          'phone': phone,
          'email': email,
          'search_text': search,
          'raw_json': jsonEncode(c),
          'updated_at_ms': now,
        },
        conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<int> countCustomers() async {
    final db = await _open();
    final rows = await db.rawQuery('SELECT COUNT(*) as c FROM cache_customers');
    if (rows.isEmpty) return 0;
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<List<Map<String, dynamic>>> searchCustomers({
    required String query,
    int limit = 50,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final db = await _open();
    final like = '%${q.toLowerCase()}%';
    final rows = await db.query(
      'cache_customers',
      columns: const ['raw_json'],
      where: 'search_text LIKE ?',
      whereArgs: [like],
      limit: limit,
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows
        .map((r) => jsonDecode(r['raw_json'] as String) as Map<String, dynamic>)
        .toList();
  }

  Future<List<Map<String, dynamic>>> listCustomers({int limit = 200}) async {
    final db = await _open();
    final rows = await db.query(
      'cache_customers',
      columns: const ['raw_json'],
      limit: limit,
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows
        .map((r) => jsonDecode(r['raw_json'] as String) as Map<String, dynamic>)
        .toList();
  }

  Future<void> upsertSuppliers(List<Map<String, dynamic>> items) async {
    final db = await _open();
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final batch = db.batch();
    for (final s in items) {
      final id = (s['supplier_id'] as num?)?.toInt() ?? 0;
      if (id <= 0) continue;
      final name = (s['name'] as String? ?? '').trim();
      final phone = (s['phone'] as String?)?.trim();
      final email = (s['email'] as String?)?.trim();
      final search = _searchText([name, phone, email]);
      batch.insert(
        'cache_suppliers',
        {
          'supplier_id': id,
          'name': name,
          'phone': phone,
          'email': email,
          'search_text': search,
          'raw_json': jsonEncode(s),
          'updated_at_ms': now,
        },
        conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> searchSuppliers({
    required String query,
    int limit = 50,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final db = await _open();
    final like = '%${q.toLowerCase()}%';
    final rows = await db.query(
      'cache_suppliers',
      columns: const ['raw_json'],
      where: 'search_text LIKE ?',
      whereArgs: [like],
      limit: limit,
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows
        .map((r) => jsonDecode(r['raw_json'] as String) as Map<String, dynamic>)
        .toList();
  }

  Future<List<Map<String, dynamic>>> listSuppliers({int limit = 200}) async {
    final db = await _open();
    final rows = await db.query(
      'cache_suppliers',
      columns: const ['raw_json'],
      limit: limit,
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows
        .map((r) => jsonDecode(r['raw_json'] as String) as Map<String, dynamic>)
        .toList();
  }

  Future<void> upsertPaymentMethods(List<Map<String, dynamic>> items) async {
    final db = await _open();
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    // Payment methods are small and treated as an authoritative list.
    // Replace the table to avoid stale/duplicate entries lingering across syncs.
    await db.delete('cache_payment_methods');
    final batch = db.batch();
    for (final m in items) {
      final id = (m['method_id'] as num?)?.toInt() ?? 0;
      if (id <= 0) continue;
      final name = (m['name'] as String? ?? '').trim();
      batch.insert(
        'cache_payment_methods',
        {
          'method_id': id,
          'name': name,
          'raw_json': jsonEncode(m),
          'updated_at_ms': now,
        },
        conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<int> countPaymentMethods() async {
    final db = await _open();
    final rows =
        await db.rawQuery('SELECT COUNT(*) as c FROM cache_payment_methods');
    if (rows.isEmpty) return 0;
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<List<Map<String, dynamic>>> listPaymentMethods() async {
    final db = await _open();
    final rows = await db.query(
      'cache_payment_methods',
      columns: const ['raw_json'],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows
        .map((r) => jsonDecode(r['raw_json'] as String) as Map<String, dynamic>)
        .toList();
  }

  Future<void> upsertCurrencies(List<Map<String, dynamic>> items) async {
    final db = await _open();
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final batch = db.batch();
    for (final c in items) {
      final id = (c['currency_id'] as num?)?.toInt() ?? 0;
      if (id <= 0) continue;
      final code = (c['code'] as String? ?? '').trim();
      if (code.isEmpty) continue;
      final symbol = (c['symbol'] as String?)?.trim();
      final isBase =
          (c['is_base_currency'] as bool?) ?? (c['is_base'] as bool?) ?? false;
      final rate = (c['exchange_rate'] as num?)?.toDouble() ??
          (c['rate'] as num?)?.toDouble() ??
          1.0;
      batch.insert(
        'cache_currencies',
        {
          'currency_id': id,
          'code': code,
          'symbol': symbol,
          'is_base': isBase ? 1 : 0,
          'exchange_rate': rate,
          'raw_json': jsonEncode(c),
          'updated_at_ms': now,
        },
        conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> listCurrencies() async {
    final db = await _open();
    final rows = await db.query(
      'cache_currencies',
      columns: const ['raw_json'],
      orderBy: 'is_base DESC, code COLLATE NOCASE ASC',
    );
    return rows
        .map((r) => jsonDecode(r['raw_json'] as String) as Map<String, dynamic>)
        .toList();
  }

  Future<void> upsertPaymentMethodCurrencies(
      List<Map<String, dynamic>> items) async {
    final db = await _open();
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    // Replace mapping table to prevent stale currencies lingering across updates.
    await db.delete('cache_payment_method_currencies');
    final batch = db.batch();
    for (final m in items) {
      final methodId = (m['method_id'] as num?)?.toInt() ?? 0;
      final currencyId = (m['currency_id'] as num?)?.toInt() ?? 0;
      if (methodId <= 0 || currencyId <= 0) continue;
      final rate = (m['exchange_rate'] as num?)?.toDouble() ??
          (m['rate'] as num?)?.toDouble() ??
          1.0;
      batch.insert(
        'cache_payment_method_currencies',
        {
          'method_id': methodId,
          'currency_id': currencyId,
          'exchange_rate': rate,
          'raw_json': jsonEncode(m),
          'updated_at_ms': now,
        },
        conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<Map<int, List<Map<String, dynamic>>>>
      listPaymentMethodCurrenciesGrouped() async {
    final db = await _open();
    final rows = await db.query(
      'cache_payment_method_currencies',
      columns: const ['method_id', 'currency_id', 'exchange_rate'],
      orderBy: 'method_id ASC, currency_id ASC',
    );
    final grouped = <int, List<Map<String, dynamic>>>{};
    for (final r in rows) {
      final mid = (r['method_id'] as int?) ?? 0;
      final cid = (r['currency_id'] as int?) ?? 0;
      if (mid <= 0 || cid <= 0) continue;
      final rate = (r['exchange_rate'] as num?)?.toDouble() ?? 1.0;
      grouped.putIfAbsent(mid, () => []);
      grouped[mid]!.add({
        'currency_id': cid,
        'rate': rate,
        'exchange_rate': rate,
      });
    }
    return grouped;
  }

  Future<void> upsertExpenseCategories(List<Map<String, dynamic>> items) async {
    final db = await _open();
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final batch = db.batch();
    for (final c in items) {
      final id = (c['category_id'] as num?)?.toInt() ?? 0;
      if (id <= 0) continue;
      final name = (c['name'] as String? ?? '').trim();
      batch.insert(
        'cache_expense_categories',
        {
          'category_id': id,
          'name': name,
          'raw_json': jsonEncode(c),
          'updated_at_ms': now,
        },
        conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> listExpenseCategories() async {
    final db = await _open();
    final rows = await db.query(
      'cache_expense_categories',
      columns: const ['raw_json'],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows
        .map((r) => jsonDecode(r['raw_json'] as String) as Map<String, dynamic>)
        .toList();
  }

  Future<void> upsertSalesHistory({
    required int locationId,
    required List<Map<String, dynamic>> items,
  }) async {
    final db = await _open();
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final batch = db.batch();
    for (final s in items) {
      final saleId = (s['sale_id'] as num?)?.toInt() ?? 0;
      if (saleId <= 0) continue;
      final saleNumber = (s['sale_number'] ?? '').toString().trim();
      if (saleNumber.isEmpty) continue;
      String? customerName;
      final cn = s['customer_name'];
      if (cn != null) {
        final v = cn.toString().trim();
        if (v.isNotEmpty) customerName = v;
      }
      if (customerName == null || customerName.isEmpty) {
        final cust = s['customer'];
        if (cust is Map && cust['name'] != null) {
          final v = cust['name'].toString().trim();
          if (v.isNotEmpty) customerName = v;
        }
      }
      final saleDate = (s['sale_date'] ?? s['date'] ?? '').toString().trim();
      final search = _searchText([saleNumber, customerName, saleDate]);
      batch.insert(
        'cache_sales_history',
        {
          'location_id': locationId,
          'sale_id': saleId,
          'sale_number': saleNumber,
          'customer_name': customerName,
          'sale_date': saleDate,
          'search_text': search,
          'raw_json': jsonEncode(s),
          'updated_at_ms': now,
        },
        conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> listSalesHistory({
    required int locationId,
    String? query,
    int limit = 100,
  }) async {
    final db = await _open();
    final q = (query ?? '').trim();
    final where = q.isEmpty
        ? 'location_id = ?'
        : 'location_id = ? AND search_text LIKE ?';
    final args = q.isEmpty
        ? <Object?>[locationId]
        : <Object?>[locationId, '%${q.toLowerCase()}%'];
    final rows = await db.query(
      'cache_sales_history',
      columns: const ['raw_json'],
      where: where,
      whereArgs: args,
      limit: limit,
      orderBy: 'sale_id DESC',
    );
    return rows
        .map((r) => jsonDecode(r['raw_json'] as String) as Map<String, dynamic>)
        .toList();
  }

  static String _searchText(List<String?> parts) {
    final buf = StringBuffer();
    var first = true;
    for (final p in parts) {
      final t = (p ?? '').trim();
      if (t.isEmpty) continue;
      if (!first) buf.write(' ');
      first = false;
      buf.write(t.toLowerCase());
    }
    return buf.toString();
  }
}
