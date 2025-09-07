import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../dashboard/controllers/location_notifier.dart';
import '../../dashboard/data/payment_methods_repository.dart';
import 'models.dart';

class PosRepository {
  PosRepository(this._dio, this._ref);

  final Dio _dio;
  final Ref _ref;

  // Small helper to unwrap list payloads that may be wrapped in {data: []}
  List<dynamic> _asList(Response res) {
    final body = res.data;
    if (body is List) return body;
    if (body is Map<String, dynamic>) {
      final data = body['data'];
      if (data is List) return data;
    }
    return const [];
  }

  // Receipt number preview using numbering sequences
  Future<String?> getNextReceiptPreview() async {
    final loc = _ref.read(locationNotifierProvider).selected;
    if (loc == null) return null;
    final res = await _dio.get('/numbering-sequences',
        queryParameters: {'location_id': loc.locationId});
    final list = _asList(res).cast<Map<String, dynamic>>();
    Map<String, dynamic>? chosen;
    // Prefer location-specific sequence over global fallback
    for (final m in list) {
      if ((m['name'] as String?)?.toLowerCase() == 'sale' && (m['location_id'] as int?) == loc.locationId) {
        chosen = m;
        break;
      }
    }
    // Fallback to global company-level sequence (location_id == null)
    chosen ??= list.firstWhere(
      (m) => (m['name'] as String?)?.toLowerCase() == 'sale' && m['location_id'] == null,
      orElse: () => <String, dynamic>{},
    );
    if (chosen.isEmpty) return null;
    final prefix = chosen['prefix'] as String? ?? '';
    final len = (chosen['sequence_length'] as num?)?.toInt() ?? 6;
    final curr = (chosen['current_number'] as num?)?.toInt() ?? 0;
    final next = curr + 1;
    final padded = next.toString().padLeft(len, '0');
    return '$prefix$padded';
  }

  Future<List<PosProductDto>> searchProducts(String query) async {
    final loc = _ref.read(locationNotifierProvider).selected;
    if (loc == null) return const [];
    final res = await _dio.get('/pos/products', queryParameters: {
      'search': query,
      'location_id': loc.locationId,
    });
    final list = _asList(res);
    return list
        .map((e) => PosProductDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<PosCustomerDto>> searchCustomers(String query) async {
    final res = await _dio.get('/pos/customers', queryParameters: {
      'search': query,
    });
    final list = _asList(res);
    return list
        .map((e) => PosCustomerDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PosCustomerDto> quickAddCustomer({
    required String name,
    String? phone,
  }) async {
    final res = await _dio.post('/customers', data: {
      'name': name,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    });
    final body = res.data is Map<String, dynamic> ? res.data['data'] : res.data;
    return PosCustomerDto.fromJson(body as Map<String, dynamic>);
  }

  Future<List<PaymentMethodDto>> getPaymentMethods() async {
    final res = await _dio.get('/pos/payment-methods');
    final list = _asList(res);
    return list
        .map((e) => PaymentMethodDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PosCheckoutResult> checkout({
    int? customerId,
    required List<PosCartItem> items,
    int? paymentMethodId,
    required double paidAmount,
    double discountAmount = 0.0,
    int? saleId,
    List<PosPaymentLineDto>? payments,
  }) async {
    final loc = _ref.read(locationNotifierProvider).selected;
    if (loc == null) {
      throw Exception('Select a location first');
    }
    final payload = {
      if (saleId != null) 'sale_id': saleId,
      if (customerId != null) 'customer_id': customerId,
      'items': items
          .map((i) => {
                'product_id': i.product.productId,
                'quantity': i.quantity,
                'unit_price': i.unitPrice,
                'discount_percentage': i.discountPercent,
              })
          .toList(),
      if (paymentMethodId != null) 'payment_method_id': paymentMethodId,
      'paid_amount': paidAmount,
      'discount_amount': discountAmount,
      if (payments != null && payments.isNotEmpty)
        'payments': payments.map((p) => p.toJson()).toList(),
    };
    final res = await _dio.post(
      '/pos/checkout',
      queryParameters: {'location_id': loc.locationId},
      data: payload,
    );
    final data = (res.data is Map<String, dynamic>)
        ? (res.data['data'] as Map<String, dynamic>?)
        : null;
    final sale = (data?['sale'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    return PosCheckoutResult.fromSale(sale);
  }

  Future<Map<String, double>> calculateTotals({
    required List<PosCartItem> items,
    required double discountAmount,
  }) async {
    final res = await _dio.post('/pos/calculate', data: {
      'items': items
          .map((i) => {
                'product_id': i.product.productId,
                'quantity': i.quantity,
                'unit_price': i.unitPrice,
                'discount_percentage': i.discountPercent,
              })
          .toList(),
      'discount_amount': discountAmount,
    });
    final map = (res.data is Map<String, dynamic>) ? (res.data['data'] as Map<String, dynamic>) : <String, dynamic>{};
    return {
      'subtotal': (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      'tax_amount': (map['tax_amount'] as num?)?.toDouble() ?? 0.0,
      'total_amount': (map['total_amount'] as num?)?.toDouble() ?? 0.0,
    };
  }

  Future<PosCheckoutResult> holdSale({
    int? customerId,
    required List<PosCartItem> items,
    double discountAmount = 0.0,
  }) async {
    final loc = _ref.read(locationNotifierProvider).selected;
    if (loc == null) {
      throw Exception('Select a location first');
    }
    final payload = {
      if (customerId != null) 'customer_id': customerId,
      'items': items
          .map((i) => {
                'product_id': i.product.productId,
                'quantity': i.quantity,
                'unit_price': i.unitPrice,
                'discount_percentage': i.discountPercent,
              })
          .toList(),
      'paid_amount': 0,
      'discount_amount': discountAmount,
    };
    final res = await _dio.post('/pos/hold', queryParameters: {'location_id': loc.locationId}, data: payload);
    final sale = (res.data is Map<String, dynamic>) ? ((res.data['data'] as Map<String, dynamic>?) ?? <String, dynamic>{}) : <String, dynamic>{};
    return PosCheckoutResult.fromSale(sale);
  }

  Future<List<HeldSaleDto>> getHeldSales() async {
    final loc = _ref.read(locationNotifierProvider).selected;
    if (loc == null) return const [];
    final res = await _dio.get('/pos/held-sales', queryParameters: {'location_id': loc.locationId});
    final list = _asList(res);
    return list.map((e) => HeldSaleDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> resumeSale(int saleId) async {
    await _dio.post('/sales/$saleId/resume');
  }

  Future<void> voidSale(int saleId) async {
    final loc = _ref.read(locationNotifierProvider).selected;
    await _dio.post('/pos/void/$saleId', queryParameters: {
      if (loc != null) 'location_id': loc.locationId,
    });
  }

  Future<SaleDto> getSaleById(int saleId) async {
    final res = await _dio.get('/sales/$saleId');
    final body = res.data is Map<String, dynamic> ? res.data['data'] : res.data;
    return SaleDto.fromJson(body as Map<String, dynamic>);
  }

  Future<List<CurrencyDto>> getCurrencies() async {
    final res = await _dio.get('/currencies');
    final list = _asList(res);
    return list.map((e) => CurrencyDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<CustomerDetailDto> getCustomerDetail(int customerId) async {
    final res = await _dio.get('/customers/$customerId');
    final body = res.data is Map<String, dynamic> ? res.data['data'] : res.data;
    return CustomerDetailDto.fromJson(body as Map<String, dynamic>);
  }
}

final posRepositoryProvider = Provider<PosRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return PosRepository(dio, ref);
});
