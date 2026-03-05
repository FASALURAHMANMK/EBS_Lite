import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/api_client.dart';
import '../../../core/offline_cache/offline_cache_providers.dart';
import '../../../core/offline_cache/offline_exception.dart';
import '../../../core/outbox/outbox_item.dart';
import '../../../core/outbox/outbox_notifier.dart';
import '../../dashboard/controllers/location_notifier.dart';
import 'models.dart';

class ExpensesRepository {
  ExpensesRepository(this._dio, this._ref);
  final Dio _dio;
  final Ref _ref;

  int? get _locationId =>
      _ref.read(locationNotifierProvider).selected?.locationId;

  List<dynamic> _extractList(Response res) {
    final body = res.data;
    if (body is List) return body;
    if (body is Map) {
      final value = body['data'];
      if (value is List) return value;
      return const [];
    }
    return const [];
  }

  Future<List<ExpenseCategoryDto>> getCategories() async {
    final outbox = _ref.read(outboxNotifierProvider.notifier);
    final store = _ref.read(cacheStoreProvider);

    if (!outbox.isOnline) {
      final cached = await store.listExpenseCategories();
      return cached.map(ExpenseCategoryDto.fromJson).toList();
    }

    final res = await _dio.get('/expenses/categories');
    final list = _extractList(res).cast<Map<String, dynamic>>();
    // ignore: unawaited_futures
    store.upsertExpenseCategories(list);
    return list.map(ExpenseCategoryDto.fromJson).toList();
  }

  Future<List<ExpenseDto>> listExpenses({
    int? categoryId,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final outbox = _ref.read(outboxNotifierProvider.notifier);
    if (!outbox.isOnline) {
      return const [];
    }
    final qp = <String, dynamic>{
      if (categoryId != null) 'category_id': categoryId,
      if (dateFrom != null)
        'date_from': dateFrom.toIso8601String().split('T').first,
      if (dateTo != null) 'date_to': dateTo.toIso8601String().split('T').first,
      if (_locationId != null) 'location_id': _locationId,
    };
    final res = await _dio.get('/expenses', queryParameters: qp);
    final list = _extractList(res).cast<Map<String, dynamic>>();
    return list.map(ExpenseDto.fromJson).toList();
  }

  Future<int> createExpense({
    required int categoryId,
    required double amount,
    required DateTime expenseDate,
    String? notes,
  }) async {
    final loc = _locationId;
    if (loc == null) {
      throw StateError('Location not selected');
    }
    final payload = <String, dynamic>{
      'category_id': categoryId,
      'amount': amount,
      'expense_date': expenseDate.toIso8601String().split('T').first,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    };

    final outbox = _ref.read(outboxNotifierProvider.notifier);
    final idemKey = const Uuid().v4();
    final headers = {
      'Idempotency-Key': idemKey,
      'X-Idempotency-Key': idemKey,
    };

    if (!outbox.isOnline) {
      await outbox.enqueue(
        OutboxItem(
          type: 'expense',
          method: 'POST',
          path: '/expenses',
          queryParams: {'location_id': loc},
          headers: headers,
          body: payload,
          idempotencyKey: idemKey,
        ),
      );
      throw OutboxQueuedException('Expense queued for sync');
    }

    Response res;
    try {
      res = await _dio.post(
        '/expenses',
        queryParameters: {'location_id': loc},
        data: payload,
        options: Options(headers: headers),
      );
    } on DioException catch (e) {
      if (outbox.isNetworkError(e)) {
        await outbox.enqueue(
          OutboxItem(
            type: 'expense',
            method: 'POST',
            path: '/expenses',
            queryParams: {'location_id': loc},
            headers: headers,
            body: payload,
            idempotencyKey: idemKey,
          ),
        );
        throw OutboxQueuedException('Expense queued for sync');
      }
      rethrow;
    }

    final data = (res.data is Map && res.data['data'] != null)
        ? res.data['data'] as Map<String, dynamic>
        : res.data as Map<String, dynamic>;
    return (data['expense_id'] as int?) ?? 0;
  }

  Future<int> createCategory(String name) async {
    final outbox = _ref.read(outboxNotifierProvider.notifier);
    if (!outbox.isOnline) {
      throw OfflineException('Managing expense categories requires internet.');
    }
    final res = await _dio.post('/expenses/categories', data: {'name': name});
    final data = (res.data is Map && res.data['data'] != null)
        ? res.data['data'] as Map<String, dynamic>
        : res.data as Map<String, dynamic>;
    return (data['category_id'] as int?) ?? 0;
  }

  Future<void> updateCategory(int id, String name) async {
    final outbox = _ref.read(outboxNotifierProvider.notifier);
    if (!outbox.isOnline) {
      throw OfflineException('Managing expense categories requires internet.');
    }
    await _dio.put('/expenses/categories/$id', data: {'name': name});
  }

  Future<void> deleteCategory(int id) async {
    final outbox = _ref.read(outboxNotifierProvider.notifier);
    if (!outbox.isOnline) {
      throw OfflineException('Managing expense categories requires internet.');
    }
    await _dio.delete('/expenses/categories/$id');
  }
}

final expensesRepositoryProvider = Provider<ExpensesRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return ExpensesRepository(dio, ref);
});
