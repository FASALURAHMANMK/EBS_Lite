import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/negative_stock_override.dart';
import '../../../core/offline_cache/offline_cache_providers.dart';
import '../../../core/outbox/outbox_notifier.dart';
import '../../dashboard/controllers/location_notifier.dart';

class SalesRepository {
  SalesRepository(this._dio, this._ref);

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

  Future<List<Map<String, dynamic>>> getSalesHistory({
    String? dateFrom,
    String? dateTo,
    int? customerId,
    int? paymentMethodId,
    int? productId,
    String? saleNumber,
    String? transactionType,
  }) async {
    final loc = _locationId;
    final outbox = _ref.read(outboxNotifierProvider.notifier);
    final store = _ref.read(cacheStoreProvider);

    if (!outbox.isOnline && loc != null) {
      final q = (saleNumber ?? '').trim();
      return (await store.listSalesHistory(
        locationId: loc,
        query: q.isEmpty ? null : q,
        limit: 150,
      ))
          .cast<Map<String, dynamic>>();
    }

    final qp = <String, dynamic>{};
    if (dateFrom != null && dateFrom.isNotEmpty) qp['date_from'] = dateFrom;
    if (dateTo != null && dateTo.isNotEmpty) qp['date_to'] = dateTo;
    if (customerId != null) qp['customer_id'] = customerId;
    if (paymentMethodId != null) qp['payment_method_id'] = paymentMethodId;
    if (productId != null) qp['product_id'] = productId;
    if (saleNumber != null && saleNumber.isNotEmpty) {
      qp['sale_number'] = saleNumber;
    }
    if (transactionType != null && transactionType.isNotEmpty) {
      qp['transaction_type'] = transactionType;
    }
    final res = await _dio.get('/sales/history',
        queryParameters: qp.isEmpty ? null : qp);
    final data = _extractList(res).cast<Map<String, dynamic>>();
    if (loc != null) {
      // ignore: unawaited_futures
      store.upsertSalesHistory(locationId: loc, items: data);
    }
    return data;
  }

  Future<List<Map<String, dynamic>>> getSaleReturns({
    String? dateFrom,
    String? dateTo,
    int? customerId,
    int? saleId,
    String? status,
    String? transactionType,
  }) async {
    final qp = <String, dynamic>{};
    if (dateFrom != null && dateFrom.isNotEmpty) qp['date_from'] = dateFrom;
    if (dateTo != null && dateTo.isNotEmpty) qp['date_to'] = dateTo;
    if (customerId != null) qp['customer_id'] = customerId;
    if (saleId != null) qp['sale_id'] = saleId;
    if (status != null && status.isNotEmpty) qp['status'] = status;
    if (transactionType != null && transactionType.isNotEmpty) {
      qp['transaction_type'] = transactionType;
    }
    final res = await _dio.get('/sale-returns',
        queryParameters: qp.isEmpty ? null : qp);
    final data = _extractList(res);
    return data.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getSaleReturn(int id) async {
    final res = await _dio.get('/sale-returns/$id');
    final body = res.data is Map && (res.data['data'] != null)
        ? res.data['data'] as Map<String, dynamic>
        : res.data as Map<String, dynamic>;
    return body;
  }

  Future<Map<String, dynamic>> getReturnableForSale(int saleId) async {
    final res = await _dio.get('/sale-returns/search/$saleId');
    final body = res.data is Map && (res.data['data'] != null)
        ? res.data['data'] as Map<String, dynamic>
        : res.data as Map<String, dynamic>;
    return body;
  }

  Future<Map<String, dynamic>> getRefundableForSale(int saleId) async {
    final res = await _dio.get('/sales/$saleId/refundable-items');
    final body = res.data is Map && (res.data['data'] != null)
        ? res.data['data'] as Map<String, dynamic>
        : res.data as Map<String, dynamic>;
    return body;
  }

  Future<int> createSaleReturn({
    required int saleId,
    required List<Map<String, dynamic>>
        items, // {product_id, quantity, unit_price}
    String? reason,
    String? overridePassword,
  }) async {
    final payload = <String, dynamic>{
      'sale_id': saleId,
      'items': items,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
      if (overridePassword != null && overridePassword.trim().isNotEmpty)
        'override_password': overridePassword.trim(),
    };
    final res = await _dio.post('/sale-returns', data: payload);
    final body = res.data is Map && (res.data['data'] != null)
        ? res.data['data'] as Map<String, dynamic>
        : res.data as Map<String, dynamic>;
    return (body['return_id'] as int?) ?? (body['returnId'] as int? ?? 0);
  }

  Future<int> createRefundInvoice({
    required int saleId,
    required List<Map<String, dynamic>> items,
    String? reason,
    String? overridePassword,
  }) async {
    final payload = <String, dynamic>{
      'items': items,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
      if (overridePassword != null && overridePassword.trim().isNotEmpty)
        'override_password': overridePassword.trim(),
    };
    final res = await _dio.post('/sales/$saleId/refund-invoice', data: payload);
    final body = res.data is Map && (res.data['data'] != null)
        ? res.data['data'] as Map<String, dynamic>
        : res.data as Map<String, dynamic>;
    return (body['sale_id'] as int?) ?? (body['saleId'] as int? ?? 0);
  }

  Future<int> createSaleReturnByCustomer({
    required int customerId,
    required List<Map<String, dynamic>> items,
    String? reason,
    String? overridePassword,
  }) async {
    final payload = <String, dynamic>{
      'customer_id': customerId,
      'items': items,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
      if (overridePassword != null && overridePassword.trim().isNotEmpty)
        'override_password': overridePassword.trim(),
    };
    final res = await _dio.post('/sale-returns/by-customer', data: payload);
    final body = res.data is Map && (res.data['data'] != null)
        ? res.data['data'] as Map<String, dynamic>
        : res.data as Map<String, dynamic>;
    return (body['return_id'] as int?) ?? (body['returnId'] as int? ?? 0);
  }

  Future<Map<String, dynamic>> getSalesSummary(
      {String? dateFrom, String? dateTo}) async {
    final qp = <String, dynamic>{};
    final loc = _locationId;
    if (loc != null) qp['location_id'] = loc;
    if (dateFrom != null && dateFrom.isNotEmpty) qp['date_from'] = dateFrom;
    if (dateTo != null && dateTo.isNotEmpty) qp['date_to'] = dateTo;
    final res = await _dio.get('/pos/sales-summary',
        queryParameters: qp.isEmpty ? null : qp);
    final body = res.data is Map && (res.data['data'] != null)
        ? res.data['data'] as Map<String, dynamic>
        : res.data as Map<String, dynamic>;
    return body;
  }

  Future<List<Map<String, dynamic>>> getQuotes({
    String? status,
    String? dateFrom,
    String? dateTo,
    int? customerId,
    String? transactionType,
  }) async {
    final qp = <String, dynamic>{};
    if (status != null && status.isNotEmpty) qp['status'] = status;
    if (dateFrom != null && dateFrom.isNotEmpty) qp['date_from'] = dateFrom;
    if (dateTo != null && dateTo.isNotEmpty) qp['date_to'] = dateTo;
    if (customerId != null) qp['customer_id'] = customerId;
    if (transactionType != null && transactionType.isNotEmpty) {
      qp['transaction_type'] = transactionType;
    }
    final res = await _dio.get('/sales/quotes',
        queryParameters: qp.isEmpty ? null : qp);
    final data = _extractList(res);
    return data.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getQuote(int id) async {
    final res = await _dio.get('/sales/quotes/$id');
    final body = res.data is Map && (res.data['data'] != null)
        ? res.data['data'] as Map<String, dynamic>
        : res.data as Map<String, dynamic>;
    return body;
  }

  Future<int> createQuote({
    int? customerId,
    String? transactionType,
    DateTime? validUntil,
    double discountAmount = 0.0,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) async {
    final loc = _locationId;
    if (loc == null) {
      throw Exception('Select a location first');
    }
    final payload = <String, dynamic>{
      if (customerId != null) 'customer_id': customerId,
      if (transactionType != null && transactionType.isNotEmpty)
        'transaction_type': transactionType,
      if (validUntil != null) 'valid_until': validUntil.toIso8601String(),
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'discount_amount': discountAmount,
      'items': items,
    };
    final res = await _dio.post(
      '/sales/quotes',
      queryParameters: {'location_id': loc},
      data: payload,
    );
    final body = res.data is Map && (res.data['data'] != null)
        ? res.data['data'] as Map<String, dynamic>
        : res.data as Map<String, dynamic>;
    return (body['quote_id'] as int?) ?? (body['quoteId'] as int? ?? 0);
  }

  Future<void> updateQuote(
    int id, {
    int? customerId,
    bool clearCustomer = false,
    String? status,
    String? transactionType,
    String? notes,
    DateTime? validUntil,
    double? discountAmount,
    List<Map<String, dynamic>>? items,
  }) async {
    final payload = <String, dynamic>{
      if (customerId != null || clearCustomer) 'customer_id': customerId,
      if (status != null && status.isNotEmpty) 'status': status,
      if (transactionType != null && transactionType.isNotEmpty)
        'transaction_type': transactionType,
      if (notes != null) 'notes': notes,
      if (validUntil != null) 'valid_until': validUntil.toIso8601String(),
      if (discountAmount != null) 'discount_amount': discountAmount,
      if (items != null) 'items': items,
    };
    await _dio.put('/sales/quotes/$id', data: payload);
  }

  Future<void> deleteQuote(int id) async {
    await _dio.delete('/sales/quotes/$id');
  }

  Future<void> printQuote(int id) async {
    await _dio.post('/sales/quotes/$id/print');
  }

  Future<Map<String, dynamic>> getQuotePrintData(int id) async {
    final res = await _dio.post('/sales/quotes/$id/print-data');
    final body = (res.data is Map<String, dynamic> && res.data['data'] != null)
        ? res.data['data'] as Map<String, dynamic>
        : res.data as Map<String, dynamic>;
    return body;
  }

  Future<int> convertQuoteToSale(int id, {String? overridePassword}) async {
    Response res;
    try {
      res = await _dio.post(
        '/sales/quotes/$id/convert',
        data: {
          if ((overridePassword ?? '').trim().isNotEmpty)
            'override_password': overridePassword!.trim(),
        },
      );
    } on DioException catch (e) {
      final stockApproval = parseNegativeStockApprovalRequired(e);
      if (stockApproval != null) throw stockApproval;
      final profitApproval = parseNegativeProfitApprovalRequired(e);
      if (profitApproval != null) throw profitApproval;
      rethrow;
    }
    final body = (res.data is Map<String, dynamic> && res.data['data'] != null)
        ? res.data['data'] as Map<String, dynamic>
        : res.data as Map<String, dynamic>;
    return (body['sale_id'] as int?) ?? 0;
  }

  Future<void> shareQuote(int id, String email) async {
    await _dio.post('/sales/quotes/$id/share', data: {'email': email});
  }

  Future<void> markQuoteShared(int id) async {
    await _dio.post('/sales/quotes/$id/share');
  }

  Future<void> updateSale(
    int id, {
    int? paymentMethodId,
    String? notes,
    String? overridePassword,
  }) async {
    final payload = <String, dynamic>{
      if (paymentMethodId != null) 'payment_method_id': paymentMethodId,
      if (notes != null) 'notes': notes,
      if (overridePassword != null && overridePassword.trim().isNotEmpty)
        'override_password': overridePassword.trim(),
    };
    await _dio.put('/sales/$id', data: payload);
  }

  Future<int> createInvoice({
    required int customerId,
    required List<Map<String, dynamic>> items,
    int? paymentMethodId,
    double paidAmount = 0,
    double discountAmount = 0,
    String? notes,
    String transactionType = 'B2B',
  }) async {
    final loc = _locationId;
    if (loc == null) {
      throw Exception('Select a location first');
    }
    final payload = <String, dynamic>{
      'customer_id': customerId,
      'transaction_type': transactionType,
      'items': items,
      'paid_amount': paidAmount,
      'discount_amount': discountAmount,
      if (paymentMethodId != null) 'payment_method_id': paymentMethodId,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    };
    final res = await _dio.post(
      '/sales',
      queryParameters: {'location_id': loc},
      data: payload,
    );
    final body = res.data is Map && (res.data['data'] != null)
        ? res.data['data'] as Map<String, dynamic>
        : res.data as Map<String, dynamic>;
    return (body['sale_id'] as int?) ?? 0;
  }
}

final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return SalesRepository(dio, ref);
});
