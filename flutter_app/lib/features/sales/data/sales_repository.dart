import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../dashboard/controllers/location_notifier.dart';

class SalesRepository {
  SalesRepository(this._dio, this._ref);

  final Dio _dio;
  final Ref _ref;

  int? get _locationId => _ref.read(locationNotifierProvider).selected?.locationId;

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
  }) async {
    final qp = <String, dynamic>{};
    if (dateFrom != null && dateFrom.isNotEmpty) qp['date_from'] = dateFrom;
    if (dateTo != null && dateTo.isNotEmpty) qp['date_to'] = dateTo;
    if (customerId != null) qp['customer_id'] = customerId;
    if (paymentMethodId != null) qp['payment_method_id'] = paymentMethodId;
    if (productId != null) qp['product_id'] = productId;
    final res = await _dio.get('/sales/history', queryParameters: qp.isEmpty ? null : qp);
    final data = _extractList(res);
    return data.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getSaleReturns({
    String? dateFrom,
    String? dateTo,
    int? customerId,
    int? saleId,
    String? status,
  }) async {
    final qp = <String, dynamic>{};
    if (dateFrom != null && dateFrom.isNotEmpty) qp['date_from'] = dateFrom;
    if (dateTo != null && dateTo.isNotEmpty) qp['date_to'] = dateTo;
    if (customerId != null) qp['customer_id'] = customerId;
    if (saleId != null) qp['sale_id'] = saleId;
    if (status != null && status.isNotEmpty) qp['status'] = status;
    final res = await _dio.get('/sale-returns', queryParameters: qp.isEmpty ? null : qp);
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

  Future<Map<String, dynamic>> getSalesSummary({String? dateFrom, String? dateTo}) async {
    final qp = <String, dynamic>{};
    final loc = _locationId;
    if (loc != null) qp['location_id'] = loc;
    if (dateFrom != null && dateFrom.isNotEmpty) qp['date_from'] = dateFrom;
    if (dateTo != null && dateTo.isNotEmpty) qp['date_to'] = dateTo;
    final res = await _dio.get('/pos/sales-summary', queryParameters: qp.isEmpty ? null : qp);
    final body = res.data is Map && (res.data['data'] != null)
        ? res.data['data'] as Map<String, dynamic>
        : res.data as Map<String, dynamic>;
    return body;
  }
}

final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return SalesRepository(dio, ref);
});

