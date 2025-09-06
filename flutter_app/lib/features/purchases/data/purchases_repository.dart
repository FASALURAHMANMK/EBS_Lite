import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../dashboard/controllers/location_notifier.dart';

class PurchasesRepository {
  PurchasesRepository(this._dio, this._ref);
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

  Future<List<Map<String, dynamic>>> getPendingOrders() async {
    final qp = <String, dynamic>{};
    final loc = _locationId;
    if (loc != null) qp['location_id'] = loc;
    final res = await _dio.get('/purchases/pending', queryParameters: qp.isEmpty ? null : qp);
    final data = _extractList(res);
    return data.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getOrders({String? status, int? supplierId}) async {
    final qp = <String, dynamic>{};
    if (status != null) qp['status'] = status;
    if (supplierId != null) qp['supplier_id'] = supplierId;
    final loc = _locationId;
    if (loc != null) qp['location_id'] = loc;
    final res = await _dio.get('/purchases', queryParameters: qp.isEmpty ? null : qp);
    final data = _extractList(res);
    return data.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getPurchase(int id) async {
    final res = await _dio.get('/purchases/$id');
    final body = res.data is Map && (res.data['data'] != null)
        ? res.data['data'] as Map<String, dynamic>
        : res.data as Map<String, dynamic>;
    return body;
  }

  Future<int> createPurchaseOrder({
    required int supplierId,
    required List<Map<String, dynamic>> items, // {product_id, quantity, unit_price, ...}
    String? referenceNumber,
    String? notes,
  }) async {
    final body = <String, dynamic>{
      'supplier_id': supplierId,
      if (_locationId != null) 'location_id': _locationId,
      if (referenceNumber != null && referenceNumber.isNotEmpty) 'reference_number': referenceNumber,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'items': items,
    };
    final res = await _dio.post('/purchase-orders', data: body);
    final data = res.data is Map && (res.data['data'] != null)
        ? res.data['data'] as Map<String, dynamic>
        : res.data as Map<String, dynamic>;
    return data['purchase_id'] as int;
  }

  Future<void> approvePurchaseOrder(int id) async {
    await _dio.put('/purchase-orders/$id/approve');
  }

  Future<void> receiveAgainstPO({required int purchaseId, required List<Map<String, dynamic>> items}) async {
    await _dio.post('/goods-receipts', data: {
      'purchase_id': purchaseId,
      'items': items,
    });
  }
}

final purchasesRepositoryProvider = Provider<PurchasesRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return PurchasesRepository(dio, ref);
});

