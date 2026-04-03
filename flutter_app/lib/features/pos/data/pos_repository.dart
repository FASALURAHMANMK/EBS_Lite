import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/api_client.dart';
import '../../../core/negative_stock_override.dart';
import '../../../core/offline_cache/offline_cache_providers.dart';
import '../../../core/offline_cache/offline_exception.dart';
import '../../../core/offline_cache/offline_numbering.dart';
import '../../../core/outbox/outbox_item.dart';
import '../../../core/outbox/outbox_notifier.dart';
import '../../accounts/controllers/training_mode_notifier.dart';
import '../../dashboard/controllers/location_notifier.dart';
import '../../dashboard/data/payment_methods_repository.dart';
import 'models.dart';

class PosRepository {
  PosRepository(this._dio, this._ref);

  final Dio _dio;
  final Ref _ref;

  Map<String, dynamic> _saleItemPayload(PosCartItem item) {
    final comboTracking = item.comboTracking
        .where((component) => component.requiresTracking)
        .map((component) => component.toJson())
        .toList();
    return {
      if (item.product.productId > 0) 'product_id': item.product.productId,
      if ((item.product.comboProductId ?? 0) > 0)
        'combo_product_id': item.product.comboProductId,
      if (item.product.barcodeId > 0) 'barcode_id': item.product.barcodeId,
      if ((item.sourceSaleDetailId ?? 0) > 0)
        'source_sale_detail_id': item.sourceSaleDetailId,
      'quantity': item.quantity,
      'unit_price': item.unitPrice,
      'discount_percentage': item.discountPercent,
      if (item.tracking != null) ...item.tracking!.toIssueJson(),
      if (comboTracking.isNotEmpty) 'combo_component_tracking': comboTracking,
    };
  }

  String _normalizedCartSignature(List<PosCartItem> items) {
    final normalized = items
        .map((item) => {
              'product_id':
                  item.product.productId > 0 ? item.product.productId : null,
              'combo_product_id': item.product.comboProductId,
              'barcode_id':
                  item.product.barcodeId > 0 ? item.product.barcodeId : null,
              'quantity': item.quantity.toStringAsFixed(4),
              'unit_price': item.unitPrice.toStringAsFixed(4),
              'discount_percentage': item.discountPercent.toStringAsFixed(4),
              'serial_numbers': [...?item.tracking?.serialNumbers]..sort(),
              'batch_allocations': (item.tracking?.batchAllocations ?? const [])
                  .map((batch) =>
                      '${batch.lotId}:${batch.quantity.toStringAsFixed(4)}')
                  .toList()
                ..sort(),
              'combo_tracking': item.comboTracking
                  .map((component) => {
                        'product_id': component.productId,
                        'barcode_id': component.barcodeId,
                        'tracking_type': component.trackingType,
                        'is_serialized': component.isSerialized,
                        'serial_numbers': [
                          ...?component.tracking?.serialNumbers
                        ]..sort(),
                        'batch_allocations': (component
                                    .tracking?.batchAllocations ??
                                const [])
                            .map((batch) =>
                                '${batch.lotId}:${batch.quantity.toStringAsFixed(4)}')
                            .toList()
                          ..sort(),
                      })
                  .toList(),
            })
        .toList()
      ..sort((a, b) => jsonEncode(a).compareTo(jsonEncode(b)));
    return jsonEncode(normalized);
  }

  String _normalizedSaleSignature(SaleDto sale) {
    final normalized = sale.items
        .where((item) => (item.productId ?? 0) > 0 && item.quantity > 0)
        .map((item) => {
              'product_id': item.productId,
              'combo_product_id': item.comboProductId,
              'barcode_id': item.barcodeId,
              'quantity': item.quantity.toStringAsFixed(4),
              'unit_price': item.unitPrice.toStringAsFixed(4),
              'discount_percentage': item.discountPercent.toStringAsFixed(4),
              'serial_numbers': [...item.serialNumbers]..sort(),
              'batch_allocations': const <String>[],
              'combo_tracking': item.comboComponentTracking
                  .map((component) => {
                        'product_id': component.productId,
                        'barcode_id': component.barcodeId,
                        'tracking_type': component.trackingType,
                        'is_serialized': component.isSerialized,
                        'serial_numbers': [
                          ...?component.tracking?.serialNumbers
                        ]..sort(),
                        'batch_allocations': (component
                                    .tracking?.batchAllocations ??
                                const [])
                            .map((batch) =>
                                '${batch.lotId}:${batch.quantity.toStringAsFixed(4)}')
                            .toList()
                          ..sort(),
                      })
                  .toList(),
            })
        .toList()
      ..sort((a, b) => jsonEncode(a).compareTo(jsonEncode(b)));
    return jsonEncode(normalized);
  }

  bool _saleEditHasChanges({
    required SaleDto baseline,
    required int? customerId,
    required List<PosCartItem> items,
    required int? paymentMethodId,
    required double paidAmount,
    required double discountAmount,
    List<PosPaymentLineDto>? payments,
  }) {
    final normalizedCustomerId = customerId ?? 0;
    final baselineCustomerId = baseline.customerId ?? 0;
    if (normalizedCustomerId != baselineCustomerId) return true;
    if ((discountAmount - baseline.discountAmount).abs() > 0.0001) return true;
    if ((paidAmount - baseline.paidAmount).abs() > 0.0001) return true;
    if ((paymentMethodId ?? 0) != (baseline.paymentMethodId ?? 0)) return true;
    if (_normalizedCartSignature(items) != _normalizedSaleSignature(baseline)) {
      return true;
    }
    if (payments != null && payments.isNotEmpty) {
      if (payments.length != 1) return true;
      final line = payments.first;
      if (line.methodId != (baseline.paymentMethodId ?? 0)) return true;
      if ((line.amount - baseline.paidAmount).abs() > 0.0001) return true;
    }
    return false;
  }

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

    final outbox = _ref.read(outboxNotifierProvider.notifier);

    // Prefer local reserved block preview so the UI matches what this device will use.
    final offlineNum = _ref.read(offlineNumberingServiceProvider);
    final localPreview = offlineNum.peekNextSaleNumber(training: false);
    if (localPreview != null && localPreview.isNotEmpty) return localPreview;

    // Receipt previews are a convenience; don't block offline operation.
    if (!outbox.isOnline) return null;
    Response res;
    try {
      res = await _dio.get('/numbering-sequences',
          queryParameters: {'location_id': loc.locationId});
    } on DioException catch (e) {
      if (outbox.isNetworkError(e)) return null;
      rethrow;
    }
    final list = _asList(res).cast<Map<String, dynamic>>();
    Map<String, dynamic>? chosen;
    // Prefer location-specific sequence over global fallback
    for (final m in list) {
      if ((m['name'] as String?)?.toLowerCase() == 'sale' &&
          (m['location_id'] as int?) == loc.locationId) {
        chosen = m;
        break;
      }
    }
    // Fallback to global company-level sequence (location_id == null)
    chosen ??= list.firstWhere(
      (m) =>
          (m['name'] as String?)?.toLowerCase() == 'sale' &&
          m['location_id'] == null,
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

    final outbox = _ref.read(outboxNotifierProvider.notifier);
    final store = _ref.read(cacheStoreProvider);

    if (!outbox.isOnline) {
      final cached = await store.searchProducts(
        locationId: loc.locationId,
        query: query,
        limit: 80,
      );
      if (cached.isEmpty) {
        final total = await store.countProducts(locationId: loc.locationId);
        if (total == 0) {
          throw OfflineException(
              'Offline product catalog not available yet. Connect to internet once to sync master data.');
        }
      }
      return cached.map(PosProductDto.fromJson).toList();
    }

    final res = await _dio.get('/pos/products', queryParameters: {
      'search': query,
      'location_id': loc.locationId,
      'include_combo_products': true,
    });
    final list = _asList(res).cast<Map<String, dynamic>>();
    // ignore: unawaited_futures
    store.upsertProducts(locationId: loc.locationId, items: list);
    return list.map(PosProductDto.fromJson).toList();
  }

  Future<List<PosCustomerDto>> searchCustomers(
    String query, {
    String? customerType,
  }) async {
    final outbox = _ref.read(outboxNotifierProvider.notifier);
    final store = _ref.read(cacheStoreProvider);

    if (!outbox.isOnline) {
      final cached = await store.searchCustomers(query: query, limit: 80);
      if (cached.isEmpty) {
        final total = await store.countCustomers();
        if (total == 0) {
          throw OfflineException(
              'Offline customer list not available yet. Connect to internet once to sync master data.');
        }
      }
      final parsed = cached.map(PosCustomerDto.fromJson).toList();
      final type = (customerType ?? '').trim().toUpperCase();
      if (type.isEmpty) return parsed;
      return parsed.where((c) => c.customerType.toUpperCase() == type).toList();
    }

    final res = await _dio.get('/pos/customers', queryParameters: {
      'search': query,
      if ((customerType ?? '').trim().isNotEmpty)
        'customer_type': customerType!.trim().toUpperCase(),
    });
    final list = _asList(res).cast<Map<String, dynamic>>();
    // ignore: unawaited_futures
    store.upsertCustomers(list);
    return list.map(PosCustomerDto.fromJson).toList();
  }

  Future<PosCustomerDto> quickAddCustomer({
    required String name,
    String? phone,
  }) async {
    final outbox = _ref.read(outboxNotifierProvider.notifier);
    if (!outbox.isOnline) {
      throw OfflineException(
          'Adding a customer requires an online connection.');
    }
    final res = await _dio.post('/customers', data: {
      'name': name,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    });
    final body = res.data is Map<String, dynamic> ? res.data['data'] : res.data;
    return PosCustomerDto.fromJson(body as Map<String, dynamic>);
  }

  Future<List<PaymentMethodDto>> getPaymentMethods() async {
    final outbox = _ref.read(outboxNotifierProvider.notifier);
    final store = _ref.read(cacheStoreProvider);

    if (!outbox.isOnline) {
      final cached = await store.listPaymentMethods();
      if (cached.isEmpty) {
        final total = await store.countPaymentMethods();
        if (total == 0) {
          throw OfflineException(
              'Offline payment methods not available yet. Connect to internet once to sync master data.');
        }
      }
      return cached.map(PaymentMethodDto.fromJson).toList();
    }

    final res = await _dio.get('/pos/payment-methods');
    final list = _asList(res).cast<Map<String, dynamic>>();
    // ignore: unawaited_futures
    store.upsertPaymentMethods(list);
    return list.map(PaymentMethodDto.fromJson).toList();
  }

  Future<Map<int, List<Map<String, dynamic>>>>
      getPaymentMethodCurrencies() async {
    final outbox = _ref.read(outboxNotifierProvider.notifier);
    final store = _ref.read(cacheStoreProvider);

    if (!outbox.isOnline) {
      return store.listPaymentMethodCurrenciesGrouped();
    }

    Response res;
    try {
      try {
        res = await _dio.get('/pos/payment-methods/currencies');
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) {
          // Backward compatibility for older backends.
          res = await _dio.get('/settings/payment-methods/currencies');
        } else {
          rethrow;
        }
      }
    } on DioException catch (e) {
      if (outbox.isNetworkError(e)) {
        return store.listPaymentMethodCurrenciesGrouped();
      }
      // If user doesn't have settings permissions, treat as "no mapping".
      if (e.response?.statusCode == 403) return const {};
      rethrow;
    }

    final list = _asList(res).cast<Map<String, dynamic>>();
    // ignore: unawaited_futures
    store.upsertPaymentMethodCurrencies(list);

    final grouped = <int, List<Map<String, dynamic>>>{};
    for (final row in list) {
      final mid = (row['method_id'] as num?)?.toInt();
      final cid = (row['currency_id'] as num?)?.toInt();
      final rate = (row['exchange_rate'] as num?)?.toDouble();
      if (mid == null || cid == null) continue;
      grouped.putIfAbsent(mid, () => []);
      grouped[mid]!.add({
        'currency_id': cid,
        'rate': rate ?? 1.0,
        'exchange_rate': rate ?? 1.0,
      });
    }
    return grouped;
  }

  Future<PosCheckoutResult> checkout({
    String transactionType = 'RETAIL',
    int? customerId,
    required List<PosCartItem> items,
    int? paymentMethodId,
    required double paidAmount,
    double discountAmount = 0.0,
    int? saleId,
    List<PosPaymentLineDto>? payments,
    double? redeemPoints,
    String? couponCode,
    bool? autoFillRaffleCustomerData,
    String? idempotencyKey,
    String? managerOverrideToken,
    String? overrideReason,
    String? salesActionPassword,
    String? overridePassword,
  }) async {
    final loc = _ref.read(locationNotifierProvider).selected;
    if (loc == null) {
      throw Exception('Select a location first');
    }

    final outbox = _ref.read(outboxNotifierProvider.notifier);
    final trainingEnabled = _ref.read(trainingModeNotifierProvider).enabled;
    final idem = (idempotencyKey ?? '').trim().isEmpty
        ? const Uuid().v4()
        : idempotencyKey!.trim();

    // Offline-first: allocate the receipt number on the device so the same flow
    // works online/offline and numbers never collide across devices.
    String? saleNumber;
    if (!trainingEnabled && saleId == null) {
      saleNumber = await _ref
          .read(offlineNumberingServiceProvider)
          .nextSaleNumber(training: false);
    }

    final payload = {
      if (saleId != null) 'sale_id': saleId,
      if (saleNumber != null && saleNumber.isNotEmpty)
        'sale_number': saleNumber,
      'transaction_type': normalizeSaleTransactionType(transactionType),
      if (customerId != null) 'customer_id': customerId,
      'items': items.map(_saleItemPayload).toList(),
      if (paymentMethodId != null) 'payment_method_id': paymentMethodId,
      'paid_amount': paidAmount,
      'discount_amount': discountAmount,
      if (payments != null && payments.isNotEmpty)
        'payments': payments.map((p) => p.toJson()).toList(),
      if (redeemPoints != null && redeemPoints > 0)
        'redeem_points': redeemPoints,
      if ((couponCode ?? '').trim().isNotEmpty)
        'coupon_code': couponCode!.trim(),
      if (autoFillRaffleCustomerData != null)
        'auto_fill_raffle_customer_data': autoFillRaffleCustomerData,
      if (managerOverrideToken != null &&
          managerOverrideToken.trim().isNotEmpty)
        'manager_override_token': managerOverrideToken.trim(),
      if (overrideReason != null && overrideReason.trim().isNotEmpty)
        'override_reason': overrideReason.trim(),
      if (salesActionPassword != null && salesActionPassword.trim().isNotEmpty)
        'sales_action_password': salesActionPassword.trim(),
      if (overridePassword != null && overridePassword.trim().isNotEmpty)
        'override_password': overridePassword.trim(),
    };
    final headers = <String, dynamic>{
      'Idempotency-Key': idem,
      'X-Idempotency-Key': idem,
    };
    if (!outbox.isOnline) {
      if (trainingEnabled) {
        throw Exception('Training mode checkout requires an online connection');
      }
      if (saleNumber == null || saleNumber.isEmpty) {
        throw Exception(
            'No reserved receipt numbers available. Connect to internet once and sync.');
      }
      await outbox.enqueue(
        OutboxItem(
          type: 'pos_checkout',
          method: 'POST',
          path: '/pos/checkout',
          queryParams: {'location_id': loc.locationId},
          headers: headers,
          body: payload,
          idempotencyKey: idem,
        ),
      );
      throw OutboxQueuedException('Checkout queued for sync ($saleNumber)');
    }
    Response res;
    try {
      res = await _dio.post(
        '/pos/checkout',
        queryParameters: {'location_id': loc.locationId},
        data: payload,
        options: headers.isEmpty ? null : Options(headers: headers),
      );
    } on DioException catch (e) {
      final stockApproval = parseNegativeStockApprovalRequired(e);
      if (stockApproval != null) throw stockApproval;
      final profitApproval = parseNegativeProfitApprovalRequired(e);
      if (profitApproval != null) throw profitApproval;
      if (outbox.isNetworkError(e)) {
        if (trainingEnabled) rethrow;
        await outbox.enqueue(
          OutboxItem(
            type: 'pos_checkout',
            method: 'POST',
            path: '/pos/checkout',
            queryParams: {'location_id': loc.locationId},
            headers: headers,
            body: payload,
            idempotencyKey: idem,
          ),
        );
        throw OutboxQueuedException('Checkout queued for sync ($saleNumber)');
      }
      rethrow;
    }
    final data = (res.data is Map<String, dynamic>)
        ? (res.data['data'] as Map<String, dynamic>?)
        : null;
    final sale =
        (data?['sale'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    return PosCheckoutResult.fromSale(sale);
  }

  Future<PosCheckoutResult> editSale({
    required SaleDto baseline,
    String? transactionType,
    int? customerId,
    required List<PosCartItem> items,
    int? paymentMethodId,
    required double paidAmount,
    double discountAmount = 0.0,
    List<PosPaymentLineDto>? payments,
    String? notes,
    String? salesActionPassword,
    String? overridePassword,
    String? managerOverrideToken,
    String? overrideReason,
  }) async {
    final loc = _ref.read(locationNotifierProvider).selected;
    if (loc == null) {
      throw Exception('Select a location first');
    }

    final outbox = _ref.read(outboxNotifierProvider.notifier);
    if (!outbox.isOnline) {
      throw OfflineException('Sale edits require an online connection.');
    }

    final hasChanges = _saleEditHasChanges(
      baseline: baseline,
      customerId: customerId,
      items: items,
      paymentMethodId: paymentMethodId,
      paidAmount: paidAmount,
      discountAmount: discountAmount,
      payments: payments,
    );
    if (!hasChanges) {
      return PosCheckoutResult(
        saleId: baseline.saleId,
        saleNumber: baseline.saleNumber,
        totalAmount: baseline.totalAmount,
        updatedExistingSale: true,
        unchanged: true,
      );
    }

    final baselineUpdatedAt =
        baseline.updatedAt ?? baseline.createdAt ?? baseline.saleDate;
    if (baselineUpdatedAt == null) {
      throw Exception('Sale edit baseline is missing updated_at');
    }

    final payload = {
      'baseline_updated_at': baselineUpdatedAt.toUtc().toIso8601String(),
      'transaction_type': normalizeSaleTransactionType(
          transactionType ?? baseline.transactionType),
      if (customerId != null) 'customer_id': customerId,
      'items': items.map(_saleItemPayload).toList(),
      if (paymentMethodId != null) 'payment_method_id': paymentMethodId,
      'paid_amount': paidAmount,
      'discount_amount': discountAmount,
      if (payments != null && payments.isNotEmpty)
        'payments': payments.map((p) => p.toJson()).toList(),
      if (notes != null) 'notes': notes,
      if (managerOverrideToken != null &&
          managerOverrideToken.trim().isNotEmpty)
        'manager_override_token': managerOverrideToken.trim(),
      if (overrideReason != null && overrideReason.trim().isNotEmpty)
        'override_reason': overrideReason.trim(),
      if (salesActionPassword != null && salesActionPassword.trim().isNotEmpty)
        'sales_action_password': salesActionPassword.trim(),
      if (overridePassword != null && overridePassword.trim().isNotEmpty)
        'override_password': overridePassword.trim(),
    };

    final res = await _dio.put(
      '/pos/sales/${baseline.saleId}',
      queryParameters: {'location_id': loc.locationId},
      data: payload,
    );
    final data = (res.data is Map<String, dynamic>)
        ? (res.data['data'] as Map<String, dynamic>?)
        : null;
    final sale =
        (data?['sale'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    return PosCheckoutResult.fromSale(
      sale,
      updatedExistingSale: true,
    );
  }

  Future<PosCouponValidationDto> validateCoupon({
    required String code,
    required double saleAmount,
    int? customerId,
  }) async {
    final res = await _dio.post(
      '/promotions/coupon-series/validate',
      data: {
        'code': code.trim(),
        'sale_amount': saleAmount,
        if (customerId != null) 'customer_id': customerId,
      },
    );
    final map = (res.data is Map<String, dynamic>)
        ? (res.data['data'] as Map<String, dynamic>?) ?? <String, dynamic>{}
        : <String, dynamic>{};
    return PosCouponValidationDto.fromJson(map);
  }

  Future<Map<String, double>> calculateTotals({
    required List<PosCartItem> items,
    required double discountAmount,
  }) async {
    final res = await _dio.post('/pos/calculate', data: {
      'items': items.map(_saleItemPayload).toList(),
      'discount_amount': discountAmount,
    });
    final map = (res.data is Map<String, dynamic>)
        ? (res.data['data'] as Map<String, dynamic>)
        : <String, dynamic>{};
    return {
      'subtotal': (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      'tax_amount': (map['tax_amount'] as num?)?.toDouble() ?? 0.0,
      'total_amount': (map['total_amount'] as num?)?.toDouble() ?? 0.0,
    };
  }

  Future<PosCheckoutResult> holdSale({
    String transactionType = 'RETAIL',
    int? customerId,
    required List<PosCartItem> items,
    double discountAmount = 0.0,
    String? idempotencyKey,
  }) async {
    final loc = _ref.read(locationNotifierProvider).selected;
    if (loc == null) {
      throw Exception('Select a location first');
    }
    final payload = {
      'transaction_type': normalizeSaleTransactionType(transactionType),
      if (customerId != null) 'customer_id': customerId,
      'items': items.map(_saleItemPayload).toList(),
      'paid_amount': 0,
      'discount_amount': discountAmount,
    };
    final headers = <String, dynamic>{
      if ((idempotencyKey ?? '').isNotEmpty) 'Idempotency-Key': idempotencyKey,
      if ((idempotencyKey ?? '').isNotEmpty)
        'X-Idempotency-Key': idempotencyKey,
    };
    final res = await _dio.post(
      '/pos/hold',
      queryParameters: {'location_id': loc.locationId},
      data: payload,
      options: headers.isEmpty ? null : Options(headers: headers),
    );
    final sale = (res.data is Map<String, dynamic>)
        ? ((res.data['data'] as Map<String, dynamic>?) ?? <String, dynamic>{})
        : <String, dynamic>{};
    return PosCheckoutResult.fromSale(sale);
  }

  Future<List<HeldSaleDto>> getHeldSales() async {
    final loc = _ref.read(locationNotifierProvider).selected;
    if (loc == null) return const [];
    final res = await _dio.get('/pos/held-sales',
        queryParameters: {'location_id': loc.locationId});
    final list = _asList(res);
    return list
        .map((e) => HeldSaleDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> resumeSale(int saleId) async {
    await _dio.post('/sales/$saleId/resume');
  }

  Future<void> voidSale(int saleId, {String? idempotencyKey}) async {
    // Legacy method kept for compatibility; voids now require a reason.
    throw UnimplementedError('Use voidSaleWithReason(...)');
  }

  Future<void> voidSaleWithReason(
    int saleId, {
    required String reason,
    String? managerOverrideToken,
    String? idempotencyKey,
  }) async {
    final loc = _ref.read(locationNotifierProvider).selected;
    final key =
        (idempotencyKey ?? '').isEmpty ? 'void-$saleId' : idempotencyKey!;
    final headers = <String, dynamic>{
      'Idempotency-Key': key,
      'X-Idempotency-Key': key,
    };
    final payload = <String, dynamic>{
      'reason': reason.trim(),
      if (managerOverrideToken != null &&
          managerOverrideToken.trim().isNotEmpty)
        'manager_override_token': managerOverrideToken.trim(),
    };
    await _dio.post(
      '/pos/void/$saleId',
      queryParameters: {
        if (loc != null) 'location_id': loc.locationId,
      },
      data: payload,
      options: Options(headers: headers),
    );
  }

  Future<SaleDto> getSaleById(int saleId) async {
    final res = await _dio.get('/sales/$saleId');
    final body = res.data is Map<String, dynamic> ? res.data['data'] : res.data;
    return SaleDto.fromJson(body as Map<String, dynamic>);
  }

  Future<List<CurrencyDto>> getCurrencies() async {
    final outbox = _ref.read(outboxNotifierProvider.notifier);
    final store = _ref.read(cacheStoreProvider);

    if (!outbox.isOnline) {
      final cached = await store.listCurrencies();
      if (cached.isEmpty) {
        throw OfflineException(
            'Offline currencies not available yet. Connect to internet once to sync master data.');
      }
      return cached.map(CurrencyDto.fromJson).toList();
    }

    Response res;
    try {
      res = await _dio.get('/currencies');
    } on DioException catch (e) {
      if (outbox.isNetworkError(e)) {
        final cached = await store.listCurrencies();
        if (cached.isNotEmpty) {
          return cached.map(CurrencyDto.fromJson).toList();
        }
      }
      rethrow;
    }

    final list = _asList(res).cast<Map<String, dynamic>>();
    // ignore: unawaited_futures
    store.upsertCurrencies(list);
    return list.map(CurrencyDto.fromJson).toList();
  }

  Future<Map<String, dynamic>> getPrintData(
      {int? invoiceId, String? saleNumber}) async {
    final payload = <String, dynamic>{
      if (invoiceId != null) 'invoice_id': invoiceId,
      if (saleNumber != null && saleNumber.isNotEmpty)
        'sale_number': saleNumber,
    };
    final res = await _dio.post('/pos/print', data: payload);
    final body = (res.data is Map<String, dynamic>)
        ? (res.data['data'] as Map<String, dynamic>?)
        : null;
    return body ?? <String, dynamic>{};
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
