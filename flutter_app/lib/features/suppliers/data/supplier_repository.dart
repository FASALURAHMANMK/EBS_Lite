import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../dashboard/controllers/location_notifier.dart';
import 'models.dart';

class SupplierRepository {
  SupplierRepository(this._dio, this._ref);
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

  Future<List<SupplierDto>> getSuppliers({String? search}) async {
    final qp = <String, dynamic>{};
    if (search != null && search.trim().isNotEmpty) qp['search'] = search.trim();
    final res = await _dio.get('/suppliers', queryParameters: qp);
    final data = _extractList(res);
    return data.map((e) => SupplierDto.fromJson(e as Map<String, dynamic>)).toList();
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

  Future<List<Map<String, dynamic>>> getPurchases({required int supplierId}) async {
    final qp = <String, dynamic>{
      'supplier_id': supplierId,
    };
    final loc = _locationId;
    if (loc != null) qp['location_id'] = loc;
    final res = await _dio.get('/purchases', queryParameters: qp);
    final data = _extractList(res);
    return data.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getPurchaseReturns({required int supplierId}) async {
    final qp = <String, dynamic>{
      'supplier_id': supplierId,
    };
    final loc = _locationId;
    if (loc != null) qp['location_id'] = loc;
    final res = await _dio.get('/purchase-returns', queryParameters: qp);
    final data = _extractList(res);
    return data.cast<Map<String, dynamic>>();
  }

  Future<List<SupplierPaymentDto>> getPayments({required int supplierId}) async {
    final qp = <String, dynamic>{'supplier_id': supplierId};
    final loc = _locationId;
    if (loc != null) qp['location_id'] = loc;
    final res = await _dio.get('/payments', queryParameters: qp);
    final data = _extractList(res);
    return data.map((e) => SupplierPaymentDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<SupplierDto> createSupplier({required String name, String? contact, String? phone, String? email, String? address, int? paymentTerms, double? creditLimit}) async {
    final body = <String, dynamic>{'name': name};
    if (contact != null) body['contact_person'] = contact;
    if (phone != null) body['phone'] = phone;
    if (email != null) body['email'] = email;
    if (address != null) body['address'] = address;
    if (paymentTerms != null) body['payment_terms'] = paymentTerms;
    if (creditLimit != null) body['credit_limit'] = creditLimit;
    final res = await _dio.post('/suppliers', data: body);
    final bodyRes = res.data is Map<String, dynamic> ? res.data['data'] : res.data;
    return SupplierDto.fromJson(bodyRes as Map<String, dynamic>);
  }

  Future<SupplierDto> updateSupplier({required int supplierId, String? name, String? contact, String? phone, String? email, String? address, int? paymentTerms, double? creditLimit, bool? isActive}) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (contact != null) body['contact_person'] = contact;
    if (phone != null) body['phone'] = phone;
    if (email != null) body['email'] = email;
    if (address != null) body['address'] = address;
    if (paymentTerms != null) body['payment_terms'] = paymentTerms;
    if (creditLimit != null) body['credit_limit'] = creditLimit;
    if (isActive != null) body['is_active'] = isActive;
    final res = await _dio.put('/suppliers/$supplierId', data: body);
    final bodyRes = res.data is Map<String, dynamic> ? res.data['data'] : res.data;
    return SupplierDto.fromJson(bodyRes as Map<String, dynamic>);
  }
}

final supplierRepositoryProvider = Provider<SupplierRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return SupplierRepository(dio, ref);
});

