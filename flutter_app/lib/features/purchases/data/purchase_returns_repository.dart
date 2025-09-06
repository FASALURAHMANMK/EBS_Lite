import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../dashboard/controllers/location_notifier.dart';

class PurchaseReturnsRepository {
  PurchaseReturnsRepository(this._dio, this._ref);
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

  Future<List<Map<String, dynamic>>> getReturns({int? purchaseId}) async {
    final qp = <String, dynamic>{};
    final loc = _locationId;
    if (loc != null) qp['location_id'] = loc;
    if (purchaseId != null) qp['purchase_id'] = purchaseId;
    final res = await _dio.get('/purchase-returns', queryParameters: qp.isEmpty ? null : qp);
    final data = _extractList(res);
    return data.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getReturn(int id) async {
    final res = await _dio.get('/purchase-returns/$id');
    final body = res.data is Map && (res.data['data'] != null)
        ? res.data['data'] as Map<String, dynamic>
        : res.data as Map<String, dynamic>;
    return body;
  }

  Future<int> createReturn({
    required int purchaseId,
    required List<Map<String, dynamic>> items, // {purchase_detail_id?, product_id, quantity, unit_price}
    String? reason,
  }) async {
    final body = <String, dynamic>{
      'purchase_id': purchaseId,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
      'items': items,
    };
    final qp = <String, dynamic>{};
    final loc = _locationId;
    if (loc != null) qp['location_id'] = loc;
    final res = await _dio.post('/purchase-returns', data: body, queryParameters: qp.isEmpty ? null : qp);
    final data = res.data is Map && (res.data['data'] != null)
        ? res.data['data'] as Map<String, dynamic>
        : res.data as Map<String, dynamic>;
    return data['return_id'] as int;
  }

  Future<void> uploadReceipt({required int returnId, required String filePath, String? receiptNumber}) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
      if (receiptNumber != null && receiptNumber.isNotEmpty) 'number': receiptNumber,
    });
    await _dio.post('/purchase-returns/$returnId/receipt', data: form);
  }
}

final purchaseReturnsRepositoryProvider = Provider<PurchaseReturnsRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return PurchaseReturnsRepository(dio, ref);
});
