import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../dashboard/controllers/location_notifier.dart';
import 'models.dart';

class CustomerRepository {
  CustomerRepository(this._dio, this._ref);
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

  Future<List<CustomerDto>> getCustomers({String? search}) async {
    final qp = <String, dynamic>{};
    if (search != null && search.trim().isNotEmpty) qp['search'] = search.trim();
    final res = await _dio.get('/customers', queryParameters: qp.isEmpty ? null : qp);
    final data = _extractList(res);
    return data.map((e) => CustomerDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<CustomerDto> getCustomer(int id) async {
    final res = await _dio.get('/customers/$id');
    final body = res.data is Map<String, dynamic> ? res.data['data'] : res.data;
    return CustomerDto.fromJson(body as Map<String, dynamic>);
  }

  Future<CustomerSummaryDto> getCustomerSummary(int id) async {
    final res = await _dio.get('/customers/$id/summary');
    final body = res.data is Map<String, dynamic> ? res.data['data'] : res.data;
    return CustomerSummaryDto.fromJson(body as Map<String, dynamic>);
  }

  Future<List<Map<String, dynamic>>> getSales({required int customerId}) async {
    final qp = <String, dynamic>{'customer_id': customerId};
    final loc = _locationId;
    if (loc != null) qp['location_id'] = loc;
    final res = await _dio.get('/sales', queryParameters: qp);
    final data = _extractList(res);
    return data.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getSaleReturns({required int customerId}) async {
    final qp = <String, dynamic>{'customer_id': customerId};
    final res = await _dio.get('/sale-returns', queryParameters: qp);
    final data = _extractList(res);
    return data.cast<Map<String, dynamic>>();
  }

  Future<List<CustomerCollectionDto>> getCollections({required int customerId}) async {
    final qp = <String, dynamic>{'customer_id': customerId};
    final res = await _dio.get('/collections', queryParameters: qp);
    final data = _extractList(res);
    return data.map((e) => CustomerCollectionDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Map<String, dynamic>>> getOutstandingInvoices({required int customerId}) async {
    // Use history endpoint (no location requirement) and compute outstanding client-side
    final qp = <String, dynamic>{'customer_id': customerId};
    final res = await _dio.get('/sales/history', queryParameters: qp);
    final data = _extractList(res);
    return data.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getPaymentMethods() async {
    // Use company-defined payment methods
    final res = await _dio.get('/settings/payment-methods');
    final data = _extractList(res);
    return data.cast<Map<String, dynamic>>();
  }

  Future<int> createCollection({
    required int customerId,
    required double amount,
    int? paymentMethodId,
    DateTime? receivedDate,
    String? reference,
    String? notes,
    List<Map<String, dynamic>>? invoices, // [{sale_id, amount}]
  }) async {
    final payload = <String, dynamic>{
      'customer_id': customerId,
      'amount': amount,
      if (paymentMethodId != null) 'payment_method_id': paymentMethodId,
      if (receivedDate != null) 'received_date': receivedDate.toIso8601String().split('T').first,
      if (reference != null && reference.isNotEmpty) 'reference': reference,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (invoices != null && invoices.isNotEmpty) 'invoices': invoices,
    };
    final loc = _locationId;
    if (loc == null) {
      throw StateError('Location not selected');
    }
    final res = await _dio.post('/collections', data: payload, queryParameters: {'location_id': loc});
    final body = res.data is Map && (res.data['data'] != null)
        ? res.data['data'] as Map<String, dynamic>
        : res.data as Map<String, dynamic>;
    return (body['collection_id'] as int?) ?? 0;
  }

  Future<CustomerDto> createCustomer({
    required String name,
    String? phone,
    String? email,
    String? address,
    String? taxNumber,
    int? paymentTerms,
    double? creditLimit,
  }) async {
    final body = <String, dynamic>{'name': name};
    if (phone != null) body['phone'] = phone;
    if (email != null) body['email'] = email;
    if (address != null) body['address'] = address;
    if (taxNumber != null) body['tax_number'] = taxNumber;
    if (paymentTerms != null) body['payment_terms'] = paymentTerms;
    if (creditLimit != null) body['credit_limit'] = creditLimit;
    final res = await _dio.post('/customers', data: body);
    final bodyRes = res.data is Map<String, dynamic> ? res.data['data'] : res.data;
    return CustomerDto.fromJson(bodyRes as Map<String, dynamic>);
  }

  Future<CustomerDto> updateCustomer({
    required int customerId,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? taxNumber,
    int? paymentTerms,
    double? creditLimit,
    bool? isActive,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (phone != null) body['phone'] = phone;
    if (email != null) body['email'] = email;
    if (address != null) body['address'] = address;
    if (taxNumber != null) body['tax_number'] = taxNumber;
    if (paymentTerms != null) body['payment_terms'] = paymentTerms;
    if (creditLimit != null) body['credit_limit'] = creditLimit;
    if (isActive != null) body['is_active'] = isActive;
    final res = await _dio.put('/customers/$customerId', data: body);
    final bodyRes = res.data is Map<String, dynamic> ? res.data['data'] : res.data;
    return CustomerDto.fromJson(bodyRes as Map<String, dynamic>);
  }
}

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return CustomerRepository(dio, ref);
});
