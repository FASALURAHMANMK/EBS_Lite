import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cache_db.dart';
import 'cache_store.dart';

final cacheDbProvider = Provider<CacheDb>((ref) => CacheDb());

final cacheStoreProvider = Provider<CacheStore>((ref) {
  final db = ref.watch(cacheDbProvider);
  return CacheStore(db);
});
