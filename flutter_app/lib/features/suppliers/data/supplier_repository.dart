import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/offline_cache/offline_cache_providers.dart';
import '../../../core/outbox/outbox_notifier.dart';
import '../../dashboard/controllers/location_notifier.dart';
import 'models.dart';

class SupplierRepository {
  SupplierRepository(this._dio, this._ref);
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

  Future<List<SupplierDto>> getSuppliers({
    String? search,
    bool? isMercantile,
    bool? isNonMercantile,
  }) async {
    final outbox = _ref.read(outboxNotifierProvider.notifier);
    final store = _ref.read(cacheStoreProvider);
    final q = (search ?? '').trim();

    if (!outbox.isOnline) {
      final cached = q.isEmpty
          ? await store.listSuppliers(limit: 300)
          : await store.searchSuppliers(query: q, limit: 300);
      return cached
          .map(SupplierDto.fromJson)
          .where((supplier) =>
              isMercantile == null || supplier.isMercantile == isMercantile)
          .where((supplier) =>
              isNonMercantile == null ||
              supplier.isNonMercantile == isNonMercantile)
          .toList();
    }

    final qp = <String, dynamic>{};
    if (search != null && search.trim().isNotEmpty) {
      qp['search'] = search.trim();
    }
    if (isMercantile != null) {
      qp['is_mercantile'] = isMercantile;
    }
    if (isNonMercantile != null) {
      qp['is_non_mercantile'] = isNonMercantile;
    }
    final res = await _dio.get('/suppliers', queryParameters: qp);
    final data = _extractList(res);
    // ignore: unawaited_futures
    store.upsertSuppliers(data.cast<Map<String, dynamic>>());
    return data
        .map((e) => SupplierDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SupplierDto> getSupplier(int id) async {
    final res = await _dio.get('/suppliers/$id');
    final body = res.data is Map<String, dynamic> ? res.data['data'] : res.data;
    return SupplierDto.fromJson(body as Map<String, dynamic>);
  }

  Future<SupplierSummaryDto> getSupplierSummary(int id) async {
    final res = await _dio.get('/suppliers/$id/summary');
    final body = res.data is Map<String, dynamic> ? res.data['data'] : res.data;
    return SupplierSummaryDto.fromJson(body as Map<String, dynamic>);
  }

  Future<List<Map<String, dynamic>>> getPurchases(
      {required int supplierId}) async {
    final qp = <String, dynamic>{
      'supplier_id': supplierId,
    };
    final loc = _locationId;
    if (loc != null) qp['location_id'] = loc;
    final res = await _dio.get('/purchases', queryParameters: qp);
    final data = _extractList(res);
    return data.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getPurchaseReturns(
      {required int supplierId}) async {
    final qp = <String, dynamic>{
      'supplier_id': supplierId,
    };
    final loc = _locationId;
    if (loc != null) qp['location_id'] = loc;
    final res = await _dio.get('/purchase-returns', queryParameters: qp);
    final data = _extractList(res);
    return data.cast<Map<String, dynamic>>();
  }

  Future<List<SupplierPaymentDto>> getPayments(
      {required int supplierId}) async {
    final qp = <String, dynamic>{'supplier_id': supplierId};
    final loc = _locationId;
    if (loc != null) qp['location_id'] = loc;
    final res = await _dio.get('/payments', queryParameters: qp);
    final data = _extractList(res);
    return data
        .map((e) => SupplierPaymentDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getOutstandingPurchases(
      {required int supplierId}) async {
    final loc = _locationId;
    if (loc == null) {
      throw StateError('Location not selected');
    }
    final qp = <String, dynamic>{
      'supplier_id': supplierId,
      'location_id': loc,
    };
    final res = await _dio.get('/purchases/history', queryParameters: qp);
    final data = _extractList(res);
    return data.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getPaymentMethods() async {
    final outbox = _ref.read(outboxNotifierProvider.notifier);
    final store = _ref.read(cacheStoreProvider);

    if (!outbox.isOnline) {
      return (await store.listPaymentMethods()).cast<Map<String, dynamic>>();
    }

    final res = await _dio.get('/settings/payment-methods');
    final data = _extractList(res).cast<Map<String, dynamic>>();
    // ignore: unawaited_futures
    store.upsertPaymentMethods(data);
    return data;
  }

  Future<int> createPayment({
    int? supplierId,
    int? purchaseId,
    required double amount,
    int? paymentMethodId,
    DateTime? paymentDate,
    String? reference,
    String? notes,
  }) async {
    final loc = _locationId;
    if (loc == null) {
      throw StateError('Location not selected');
    }
    final payload = <String, dynamic>{
      'amount': amount,
      if (supplierId != null) 'supplier_id': supplierId,
      if (purchaseId != null) 'purchase_id': purchaseId,
      if (paymentMethodId != null) 'payment_method_id': paymentMethodId,
      if (paymentDate != null)
        'payment_date': paymentDate.toIso8601String().split('T').first,
      if (reference != null && reference.isNotEmpty)
        'reference_number': reference,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };
    final res = await _dio.post('/payments',
        data: payload, queryParameters: {'location_id': loc});
    final body = res.data is Map && (res.data['data'] != null)
        ? res.data['data'] as Map<String, dynamic>
        : res.data as Map<String, dynamic>;
    return (body['payment_id'] as int?) ?? 0;
  }

  Future<SupplierDto> createSupplier(
      {required String name,
      String? contact,
      String? phone,
      String? email,
      String? address,
      int? paymentTerms,
      double? creditLimit,
      required bool isMercantile,
      required bool isNonMercantile}) async {
    final body = <String, dynamic>{'name': name};
    if (contact != null) body['contact_person'] = contact;
    if (phone != null) body['phone'] = phone;
    if (email != null) body['email'] = email;
    if (address != null) body['address'] = address;
    if (paymentTerms != null) body['payment_terms'] = paymentTerms;
    if (creditLimit != null) body['credit_limit'] = creditLimit;
    body['is_mercantile'] = isMercantile;
    body['is_non_mercantile'] = isNonMercantile;
    final res = await _dio.post('/suppliers', data: body);
    final bodyRes =
        res.data is Map<String, dynamic> ? res.data['data'] : res.data;
    return SupplierDto.fromJson(bodyRes as Map<String, dynamic>);
  }

  Future<SupplierDto> updateSupplier(
      {required int supplierId,
      String? name,
      String? contact,
      String? phone,
      String? email,
      String? address,
      int? paymentTerms,
      double? creditLimit,
      bool? isMercantile,
      bool? isNonMercantile,
      bool? isActive}) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (contact != null) body['contact_person'] = contact;
    if (phone != null) body['phone'] = phone;
    if (email != null) body['email'] = email;
    if (address != null) body['address'] = address;
    if (paymentTerms != null) body['payment_terms'] = paymentTerms;
    if (creditLimit != null) body['credit_limit'] = creditLimit;
    if (isMercantile != null) body['is_mercantile'] = isMercantile;
    if (isNonMercantile != null) {
      body['is_non_mercantile'] = isNonMercantile;
    }
    if (isActive != null) body['is_active'] = isActive;
    final res = await _dio.put('/suppliers/$supplierId', data: body);
    final bodyRes =
        res.data is Map<String, dynamic> ? res.data['data'] : res.data;
    return SupplierDto.fromJson(bodyRes as Map<String, dynamic>);
  }
}

final supplierRepositoryProvider = Provider<SupplierRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return SupplierRepository(dio, ref);
});
