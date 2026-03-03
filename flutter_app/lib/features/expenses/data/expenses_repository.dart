import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/api_client.dart';
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
    final res = await _dio.get('/expenses/categories');
    final list = _extractList(res);
    return list
        .map((e) => ExpenseCategoryDto.fromJson(e as Map<String, dynamic>))
        .toList();
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
}

final expensesRepositoryProvider = Provider<ExpensesRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return ExpensesRepository(dio, ref);
});
