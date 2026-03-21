import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/file_transfer.dart';
import 'models.dart';

class PromotionsRepository {
  PromotionsRepository(this._dio);

  final Dio _dio;

  List<dynamic> _extractList(Response<dynamic> res) {
    final body = res.data;
    if (body is List) return body;
    if (body is Map) {
      final value = body['data'];
      if (value is List) return value;
    }
    return const [];
  }

  Map<String, dynamic> _extractMap(Response<dynamic> res) {
    final body = res.data;
    if (body is Map<String, dynamic>) {
      final data = body['data'];
      if (data is Map<String, dynamic>) return data;
      return body;
    }
    if (body is Map) {
      return Map<String, dynamic>.from(body);
    }
    return <String, dynamic>{};
  }

  String _fmtDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  Future<void> _downloadAndShare({
    required String endpoint,
    required String filename,
    required String subject,
    required String text,
  }) async {
    final bytes = await FileTransfer.downloadBytes(_dio, endpoint);
    final path = await FileTransfer.saveToTemp(bytes, filename);
    await FileTransfer.shareTempFile(
      filePath: path,
      filename: filename,
      mimeType: FileTransfer.guessMimeTypeFromFilename(filename) ??
          'application/octet-stream',
      subject: subject,
      text: text,
    );
  }

  Future<List<PromotionDto>> getPromotions({bool activeOnly = false}) async {
    final res = await _dio.get(
      '/promotions',
      queryParameters: activeOnly ? const {'active': 'true'} : null,
    );
    return _extractList(res)
        .whereType<Map>()
        .map((item) => PromotionDto.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Future<PromotionDto> createPromotion({
    required String name,
    String? description,
    String? discountType,
    required String discountScope,
    double? value,
    double? minAmount,
    required DateTime startDate,
    required DateTime endDate,
    String? applicableTo,
    Map<String, dynamic>? conditions,
    int? priority,
    List<PromotionProductRuleDto> productRules = const [],
  }) async {
    final body = <String, dynamic>{
      'name': name,
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      if (discountType != null && discountType.trim().isNotEmpty)
        'discount_type': discountType.trim(),
      'discount_scope': discountScope.trim(),
      if (value != null) 'value': value,
      if (minAmount != null) 'min_amount': minAmount,
      'start_date': _fmtDate(startDate),
      'end_date': _fmtDate(endDate),
      if (applicableTo != null && applicableTo.trim().isNotEmpty)
        'applicable_to': applicableTo.trim(),
      if (conditions != null && conditions.isNotEmpty) 'conditions': conditions,
      if (priority != null) 'priority': priority,
      if (productRules.isNotEmpty)
        'product_rules': productRules.map((item) => item.toJson()).toList(),
    };
    final res = await _dio.post('/promotions', data: body);
    return PromotionDto.fromJson(_extractMap(res));
  }

  Future<void> updatePromotion(
    int id, {
    String? name,
    String? description,
    String? discountType,
    String? discountScope,
    double? value,
    double? minAmount,
    DateTime? startDate,
    DateTime? endDate,
    String? applicableTo,
    Map<String, dynamic>? conditions,
    int? priority,
    List<PromotionProductRuleDto>? productRules,
    bool? isActive,
  }) async {
    final body = <String, dynamic>{
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (discountType != null) 'discount_type': discountType,
      if (discountScope != null) 'discount_scope': discountScope,
      if (value != null) 'value': value,
      if (minAmount != null) 'min_amount': minAmount,
      if (startDate != null) 'start_date': _fmtDate(startDate),
      if (endDate != null) 'end_date': _fmtDate(endDate),
      if (applicableTo != null) 'applicable_to': applicableTo,
      if (conditions != null) 'conditions': conditions,
      if (priority != null) 'priority': priority,
      if (productRules != null)
        'product_rules': productRules.map((item) => item.toJson()).toList(),
      if (isActive != null) 'is_active': isActive,
    };
    await _dio.put('/promotions/$id', data: body);
  }

  Future<void> deletePromotion(int id) async {
    await _dio.delete('/promotions/$id');
  }

  Future<PromotionImportResultDto> importPromotions({
    required String filePath,
    required String filename,
  }) async {
    final res = await _dio.post(
      '/promotions/import',
      data: FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: filename),
      }),
    );
    return PromotionImportResultDto.fromJson(_extractMap(res));
  }

  Future<void> downloadPromotionImportTemplate() async {
    await _downloadAndShare(
      endpoint: '/promotions/import-template',
      filename: 'promotions_template.xlsx',
      subject: 'Promotions import template',
      text: 'Fill this template and upload it in Promotions.',
    );
  }

  Future<void> downloadPromotionImportExample() async {
    await _downloadAndShare(
      endpoint: '/promotions/import-example',
      filename: 'promotions_example.xlsx',
      subject: 'Promotions import example',
      text: 'Example promotions import file attached.',
    );
  }

  Future<List<CouponSeriesDto>> getCouponSeries(
      {bool activeOnly = false}) async {
    final res = await _dio.get(
      '/promotions/coupon-series',
      queryParameters: activeOnly ? const {'active': 'true'} : null,
    );
    return _extractList(res)
        .whereType<Map>()
        .map(
            (item) => CouponSeriesDto.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Future<CouponSeriesDto> createCouponSeries({
    required String name,
    String? description,
    required String prefix,
    required int codeLength,
    required String discountType,
    required double discountValue,
    required double minPurchaseAmount,
    double? maxDiscountAmount,
    required DateTime startDate,
    required DateTime endDate,
    required int totalCoupons,
    required int usageLimitPerCoupon,
    required int usageLimitPerCustomer,
    bool isActive = true,
  }) async {
    final res = await _dio.post(
      '/promotions/coupon-series',
      data: {
        'name': name,
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
        'prefix': prefix,
        'code_length': codeLength,
        'discount_type': discountType,
        'discount_value': discountValue,
        'min_purchase_amount': minPurchaseAmount,
        if (maxDiscountAmount != null) 'max_discount_amount': maxDiscountAmount,
        'start_date': _fmtDate(startDate),
        'end_date': _fmtDate(endDate),
        'total_coupons': totalCoupons,
        'usage_limit_per_coupon': usageLimitPerCoupon,
        'usage_limit_per_customer': usageLimitPerCustomer,
        'is_active': isActive,
      },
    );
    return CouponSeriesDto.fromJson(_extractMap(res));
  }

  Future<void> updateCouponSeries(
    int id, {
    String? name,
    String? description,
    String? prefix,
    int? codeLength,
    String? discountType,
    double? discountValue,
    double? minPurchaseAmount,
    double? maxDiscountAmount,
    DateTime? startDate,
    DateTime? endDate,
    int? usageLimitPerCoupon,
    int? usageLimitPerCustomer,
    bool? isActive,
  }) async {
    await _dio.put(
      '/promotions/coupon-series/$id',
      data: {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (prefix != null) 'prefix': prefix,
        if (codeLength != null) 'code_length': codeLength,
        if (discountType != null) 'discount_type': discountType,
        if (discountValue != null) 'discount_value': discountValue,
        if (minPurchaseAmount != null) 'min_purchase_amount': minPurchaseAmount,
        if (maxDiscountAmount != null) 'max_discount_amount': maxDiscountAmount,
        if (startDate != null) 'start_date': _fmtDate(startDate),
        if (endDate != null) 'end_date': _fmtDate(endDate),
        if (usageLimitPerCoupon != null)
          'usage_limit_per_coupon': usageLimitPerCoupon,
        if (usageLimitPerCustomer != null)
          'usage_limit_per_customer': usageLimitPerCustomer,
        if (isActive != null) 'is_active': isActive,
      },
    );
  }

  Future<void> deleteCouponSeries(int id) async {
    await _dio.delete('/promotions/coupon-series/$id');
  }

  Future<List<CouponCodeDto>> getCouponCodes(int seriesId) async {
    final res = await _dio.get('/promotions/coupon-series/$seriesId/codes');
    return _extractList(res)
        .whereType<Map>()
        .map((item) => CouponCodeDto.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Future<CouponValidationDto> validateCouponCode({
    required String code,
    required double saleAmount,
    int? customerId,
  }) async {
    final res = await _dio.post(
      '/promotions/coupon-series/validate',
      data: {
        'code': code,
        'sale_amount': saleAmount,
        if (customerId != null) 'customer_id': customerId,
      },
    );
    return CouponValidationDto.fromJson(_extractMap(res));
  }

  Future<List<RaffleDefinitionDto>> getRaffleDefinitions({
    bool activeOnly = false,
  }) async {
    final res = await _dio.get(
      '/promotions/raffles',
      queryParameters: activeOnly ? const {'active': 'true'} : null,
    );
    return _extractList(res)
        .whereType<Map>()
        .map((item) =>
            RaffleDefinitionDto.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Future<RaffleDefinitionDto> createRaffleDefinition({
    required String name,
    String? description,
    required String prefix,
    required int codeLength,
    required DateTime startDate,
    required DateTime endDate,
    required double triggerAmount,
    required int couponsPerTrigger,
    int? maxCouponsPerSale,
    required bool defaultAutoFillCustomerData,
    required bool printAfterInvoice,
    bool isActive = true,
  }) async {
    final res = await _dio.post(
      '/promotions/raffles',
      data: {
        'name': name,
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
        'prefix': prefix,
        'code_length': codeLength,
        'start_date': _fmtDate(startDate),
        'end_date': _fmtDate(endDate),
        'trigger_amount': triggerAmount,
        'coupons_per_trigger': couponsPerTrigger,
        if (maxCouponsPerSale != null)
          'max_coupons_per_sale': maxCouponsPerSale,
        'default_auto_fill_customer_data': defaultAutoFillCustomerData,
        'print_after_invoice': printAfterInvoice,
        'is_active': isActive,
      },
    );
    return RaffleDefinitionDto.fromJson(_extractMap(res));
  }

  Future<void> updateRaffleDefinition(
    int id, {
    String? name,
    String? description,
    String? prefix,
    int? codeLength,
    DateTime? startDate,
    DateTime? endDate,
    double? triggerAmount,
    int? couponsPerTrigger,
    int? maxCouponsPerSale,
    bool? defaultAutoFillCustomerData,
    bool? printAfterInvoice,
    bool? isActive,
  }) async {
    await _dio.put(
      '/promotions/raffles/$id',
      data: {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (prefix != null) 'prefix': prefix,
        if (codeLength != null) 'code_length': codeLength,
        if (startDate != null) 'start_date': _fmtDate(startDate),
        if (endDate != null) 'end_date': _fmtDate(endDate),
        if (triggerAmount != null) 'trigger_amount': triggerAmount,
        if (couponsPerTrigger != null) 'coupons_per_trigger': couponsPerTrigger,
        if (maxCouponsPerSale != null)
          'max_coupons_per_sale': maxCouponsPerSale,
        if (defaultAutoFillCustomerData != null)
          'default_auto_fill_customer_data': defaultAutoFillCustomerData,
        if (printAfterInvoice != null) 'print_after_invoice': printAfterInvoice,
        if (isActive != null) 'is_active': isActive,
      },
    );
  }

  Future<void> deleteRaffleDefinition(int id) async {
    await _dio.delete('/promotions/raffles/$id');
  }

  Future<List<RaffleCouponDto>> getRaffleCoupons(int raffleDefinitionId) async {
    final res =
        await _dio.get('/promotions/raffles/$raffleDefinitionId/coupons');
    return _extractList(res)
        .whereType<Map>()
        .map(
            (item) => RaffleCouponDto.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Future<void> markRaffleWinner(
    int raffleCouponId, {
    required String winnerName,
    String? winnerNotes,
  }) async {
    await _dio.put(
      '/promotions/raffle-coupons/$raffleCouponId/winner',
      data: {
        'winner_name': winnerName,
        if (winnerNotes != null && winnerNotes.trim().isNotEmpty)
          'winner_notes': winnerNotes.trim(),
      },
    );
  }
}

final promotionsRepositoryProvider = Provider<PromotionsRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return PromotionsRepository(dio);
});
