import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../sqflite_factory.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

class CacheDb {
  sqflite.Database? _db;

  Future<sqflite.Database> open() async {
    if (_db != null) return _db!;

    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'ebs_cache.db');
    final factory = resolveDatabaseFactory();
    _db = await factory.openDatabase(
      path,
      options: sqflite.OpenDatabaseOptions(
        version: 3,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE cache_meta (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )
          ''');

          await db.execute('''
            CREATE TABLE cache_products (
              location_id INTEGER NOT NULL,
              product_id INTEGER NOT NULL,
              name TEXT NOT NULL,
              barcode TEXT,
              search_text TEXT NOT NULL,
              raw_json TEXT NOT NULL,
              updated_at_ms INTEGER NOT NULL,
              PRIMARY KEY (location_id, product_id)
            )
          ''');
          await db.execute(
              'CREATE INDEX idx_cache_products_loc_search ON cache_products(location_id, search_text)');

          await db.execute('''
            CREATE TABLE cache_customers (
              customer_id INTEGER PRIMARY KEY,
              name TEXT NOT NULL,
              phone TEXT,
              email TEXT,
              search_text TEXT NOT NULL,
              raw_json TEXT NOT NULL,
              updated_at_ms INTEGER NOT NULL
            )
          ''');
          await db.execute(
              'CREATE INDEX idx_cache_customers_search ON cache_customers(search_text)');

          await db.execute('''
            CREATE TABLE cache_suppliers (
              supplier_id INTEGER PRIMARY KEY,
              name TEXT NOT NULL,
              phone TEXT,
              email TEXT,
              search_text TEXT NOT NULL,
              raw_json TEXT NOT NULL,
              updated_at_ms INTEGER NOT NULL
            )
          ''');
          await db.execute(
              'CREATE INDEX idx_cache_suppliers_search ON cache_suppliers(search_text)');

          await db.execute('''
            CREATE TABLE cache_payment_methods (
              method_id INTEGER PRIMARY KEY,
              name TEXT NOT NULL,
              raw_json TEXT NOT NULL,
              updated_at_ms INTEGER NOT NULL
            )
          ''');

          await db.execute('''
            CREATE TABLE cache_expense_categories (
              category_id INTEGER PRIMARY KEY,
              name TEXT NOT NULL,
              raw_json TEXT NOT NULL,
              updated_at_ms INTEGER NOT NULL
            )
          ''');

          await db.execute('''
            CREATE TABLE cache_sales_history (
              location_id INTEGER NOT NULL,
              sale_id INTEGER NOT NULL,
              sale_number TEXT NOT NULL,
              customer_name TEXT,
              sale_date TEXT,
              search_text TEXT NOT NULL,
              raw_json TEXT NOT NULL,
              updated_at_ms INTEGER NOT NULL,
              PRIMARY KEY (location_id, sale_id)
            )
          ''');
          await db.execute(
              'CREATE INDEX idx_cache_sales_history_loc_search ON cache_sales_history(location_id, search_text)');

          await db.execute('''
            CREATE TABLE cache_currencies (
              currency_id INTEGER PRIMARY KEY,
              code TEXT NOT NULL,
              symbol TEXT,
              is_base INTEGER NOT NULL,
              exchange_rate REAL NOT NULL,
              raw_json TEXT NOT NULL,
              updated_at_ms INTEGER NOT NULL
            )
          ''');

          await db.execute('''
            CREATE TABLE cache_payment_method_currencies (
              method_id INTEGER NOT NULL,
              currency_id INTEGER NOT NULL,
              exchange_rate REAL NOT NULL,
              raw_json TEXT NOT NULL,
              updated_at_ms INTEGER NOT NULL,
              PRIMARY KEY (method_id, currency_id)
            )
          ''');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS cache_sales_history (
                location_id INTEGER NOT NULL,
                sale_id INTEGER NOT NULL,
                sale_number TEXT NOT NULL,
                customer_name TEXT,
                sale_date TEXT,
                search_text TEXT NOT NULL,
                raw_json TEXT NOT NULL,
                updated_at_ms INTEGER NOT NULL,
                PRIMARY KEY (location_id, sale_id)
              )
            ''');
            await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_cache_sales_history_loc_search ON cache_sales_history(location_id, search_text)');
          }
          if (oldVersion < 3) {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS cache_currencies (
                currency_id INTEGER PRIMARY KEY,
                code TEXT NOT NULL,
                symbol TEXT,
                is_base INTEGER NOT NULL,
                exchange_rate REAL NOT NULL,
                raw_json TEXT NOT NULL,
                updated_at_ms INTEGER NOT NULL
              )
            ''');

            await db.execute('''
              CREATE TABLE IF NOT EXISTS cache_payment_method_currencies (
                method_id INTEGER NOT NULL,
                currency_id INTEGER NOT NULL,
                exchange_rate REAL NOT NULL,
                raw_json TEXT NOT NULL,
                updated_at_ms INTEGER NOT NULL,
                PRIMARY KEY (method_id, currency_id)
              )
            ''');
          }
        },
      ),
    );
    return _db!;
  }
}
