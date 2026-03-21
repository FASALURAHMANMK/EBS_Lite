import 'dart:convert';

DateTime _parseDate(dynamic value) {
  if (value is DateTime) return value;
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}

Map<String, dynamic>? _parseMap(dynamic value) {
  if (value == null) return null;
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  if (value is String && value.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
  }
  return null;
}

List<int> _parseIntList(dynamic value) {
  if (value is List) {
    return value
        .map((item) => item is num ? item.toInt() : int.tryParse('$item'))
        .whereType<int>()
        .toList(growable: false);
  }
  return const [];
}

class PromotionProductRuleDto {
  const PromotionProductRuleDto({
    required this.promotionRuleId,
    required this.promotionId,
    required this.productId,
    this.barcodeId,
    required this.discountType,
    required this.value,
    required this.minQty,
    this.productName,
    this.barcode,
  });

  final int promotionRuleId;
  final int promotionId;
  final int productId;
  final int? barcodeId;
  final String discountType;
  final double value;
  final double minQty;
  final String? productName;
  final String? barcode;

  factory PromotionProductRuleDto.fromJson(Map<String, dynamic> json) {
    return PromotionProductRuleDto(
      promotionRuleId: (json['promotion_rule_id'] as num?)?.toInt() ?? 0,
      promotionId: (json['promotion_id'] as num?)?.toInt() ?? 0,
      productId: (json['product_id'] as num?)?.toInt() ?? 0,
      barcodeId: (json['barcode_id'] as num?)?.toInt(),
      discountType: (json['discount_type'] as String? ?? '').trim(),
      value: (json['value'] as num?)?.toDouble() ?? 0,
      minQty: (json['min_qty'] as num?)?.toDouble() ?? 0,
      productName: json['product_name'] as String?,
      barcode: json['barcode'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        if (barcodeId != null) 'barcode_id': barcodeId,
        'discount_type': discountType,
        'value': value,
        if (minQty > 0) 'min_qty': minQty,
      };
}

class PromotionDto {
  const PromotionDto({
    required this.promotionId,
    required this.companyId,
    required this.name,
    this.description,
    this.discountType,
    required this.discountScope,
    this.value,
    this.minAmount,
    required this.startDate,
    required this.endDate,
    this.applicableTo,
    this.conditions,
    required this.priority,
    required this.isActive,
    required this.productRules,
  });

  final int promotionId;
  final int companyId;
  final String name;
  final String? description;
  final String? discountType;
  final String discountScope;
  final double? value;
  final double? minAmount;
  final DateTime startDate;
  final DateTime endDate;
  final String? applicableTo;
  final Map<String, dynamic>? conditions;
  final int priority;
  final bool isActive;
  final List<PromotionProductRuleDto> productRules;

  factory PromotionDto.fromJson(Map<String, dynamic> json) {
    return PromotionDto(
      promotionId: (json['promotion_id'] as num?)?.toInt() ?? 0,
      companyId: (json['company_id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      discountType: json['discount_type'] as String?,
      discountScope: (json['discount_scope'] as String? ?? 'ORDER').trim(),
      value: (json['value'] as num?)?.toDouble(),
      minAmount: (json['min_amount'] as num?)?.toDouble(),
      startDate: _parseDate(json['start_date']),
      endDate: _parseDate(json['end_date']),
      applicableTo: json['applicable_to'] as String?,
      conditions: _parseMap(json['conditions']),
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? false,
      productRules: (json['product_rules'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) =>
              PromotionProductRuleDto.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false),
    );
  }

  List<int> get loyaltyTierIds =>
      _parseIntList(conditions?['loyalty_tier_ids']);

  List<int> get customerIds => _parseIntList(conditions?['customer_ids']);

  List<int> get productIds => _parseIntList(conditions?['product_ids']);

  List<int> get categoryIds => _parseIntList(conditions?['category_ids']);
}

class CouponSeriesDto {
  const CouponSeriesDto({
    required this.couponSeriesId,
    required this.companyId,
    required this.name,
    this.description,
    required this.prefix,
    required this.codeLength,
    required this.discountType,
    required this.discountValue,
    required this.minPurchaseAmount,
    this.maxDiscountAmount,
    required this.startDate,
    required this.endDate,
    required this.totalCoupons,
    required this.usageLimitPerCoupon,
    required this.usageLimitPerCustomer,
    required this.isActive,
    required this.availableCoupons,
    required this.redeemedCoupons,
  });

  final int couponSeriesId;
  final int companyId;
  final String name;
  final String? description;
  final String prefix;
  final int codeLength;
  final String discountType;
  final double discountValue;
  final double minPurchaseAmount;
  final double? maxDiscountAmount;
  final DateTime startDate;
  final DateTime endDate;
  final int totalCoupons;
  final int usageLimitPerCoupon;
  final int usageLimitPerCustomer;
  final bool isActive;
  final int availableCoupons;
  final int redeemedCoupons;

  factory CouponSeriesDto.fromJson(Map<String, dynamic> json) {
    return CouponSeriesDto(
      couponSeriesId: (json['coupon_series_id'] as num?)?.toInt() ?? 0,
      companyId: (json['company_id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      prefix: json['prefix'] as String? ?? '',
      codeLength: (json['code_length'] as num?)?.toInt() ?? 0,
      discountType: json['discount_type'] as String? ?? '',
      discountValue: (json['discount_value'] as num?)?.toDouble() ?? 0,
      minPurchaseAmount: (json['min_purchase_amount'] as num?)?.toDouble() ?? 0,
      maxDiscountAmount: (json['max_discount_amount'] as num?)?.toDouble(),
      startDate: _parseDate(json['start_date']),
      endDate: _parseDate(json['end_date']),
      totalCoupons: (json['total_coupons'] as num?)?.toInt() ?? 0,
      usageLimitPerCoupon:
          (json['usage_limit_per_coupon'] as num?)?.toInt() ?? 0,
      usageLimitPerCustomer:
          (json['usage_limit_per_customer'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? false,
      availableCoupons: (json['available_coupons'] as num?)?.toInt() ?? 0,
      redeemedCoupons: (json['redeemed_coupons'] as num?)?.toInt() ?? 0,
    );
  }
}

class CouponCodeDto {
  const CouponCodeDto({
    required this.couponCodeId,
    required this.couponSeriesId,
    required this.code,
    required this.status,
    required this.redeemCount,
    this.issuedToCustomerId,
    this.issuedSaleId,
    this.redeemedSaleId,
    this.issuedAt,
    this.redeemedAt,
  });

  final int couponCodeId;
  final int couponSeriesId;
  final String code;
  final String status;
  final int redeemCount;
  final int? issuedToCustomerId;
  final int? issuedSaleId;
  final int? redeemedSaleId;
  final DateTime? issuedAt;
  final DateTime? redeemedAt;

  factory CouponCodeDto.fromJson(Map<String, dynamic> json) {
    return CouponCodeDto(
      couponCodeId: (json['coupon_code_id'] as num?)?.toInt() ?? 0,
      couponSeriesId: (json['coupon_series_id'] as num?)?.toInt() ?? 0,
      code: json['code'] as String? ?? '',
      status: json['status'] as String? ?? '',
      redeemCount: (json['redeem_count'] as num?)?.toInt() ?? 0,
      issuedToCustomerId: (json['issued_to_customer_id'] as num?)?.toInt(),
      issuedSaleId: (json['issued_sale_id'] as num?)?.toInt(),
      redeemedSaleId: (json['redeemed_sale_id'] as num?)?.toInt(),
      issuedAt:
          json['issued_at'] != null ? _parseDate(json['issued_at']) : null,
      redeemedAt:
          json['redeemed_at'] != null ? _parseDate(json['redeemed_at']) : null,
    );
  }
}

class CouponValidationDto {
  const CouponValidationDto({
    required this.couponSeriesId,
    required this.seriesName,
    required this.code,
    required this.discountType,
    required this.discountValue,
    required this.discountAmount,
    required this.minPurchaseAmount,
    this.maxDiscountAmount,
  });

  final int couponSeriesId;
  final String seriesName;
  final String code;
  final String discountType;
  final double discountValue;
  final double discountAmount;
  final double minPurchaseAmount;
  final double? maxDiscountAmount;

  factory CouponValidationDto.fromJson(Map<String, dynamic> json) {
    return CouponValidationDto(
      couponSeriesId: (json['coupon_series_id'] as num?)?.toInt() ?? 0,
      seriesName: json['series_name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      discountType: json['discount_type'] as String? ?? '',
      discountValue: (json['discount_value'] as num?)?.toDouble() ?? 0,
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0,
      minPurchaseAmount: (json['min_purchase_amount'] as num?)?.toDouble() ?? 0,
      maxDiscountAmount: (json['max_discount_amount'] as num?)?.toDouble(),
    );
  }
}

class RaffleDefinitionDto {
  const RaffleDefinitionDto({
    required this.raffleDefinitionId,
    required this.companyId,
    required this.name,
    this.description,
    required this.prefix,
    required this.codeLength,
    required this.startDate,
    required this.endDate,
    required this.triggerAmount,
    required this.couponsPerTrigger,
    this.maxCouponsPerSale,
    required this.defaultAutoFillCustomerData,
    required this.printAfterInvoice,
    required this.isActive,
    required this.issuedCoupons,
    required this.winnerCount,
  });

  final int raffleDefinitionId;
  final int companyId;
  final String name;
  final String? description;
  final String prefix;
  final int codeLength;
  final DateTime startDate;
  final DateTime endDate;
  final double triggerAmount;
  final int couponsPerTrigger;
  final int? maxCouponsPerSale;
  final bool defaultAutoFillCustomerData;
  final bool printAfterInvoice;
  final bool isActive;
  final int issuedCoupons;
  final int winnerCount;

  factory RaffleDefinitionDto.fromJson(Map<String, dynamic> json) {
    return RaffleDefinitionDto(
      raffleDefinitionId: (json['raffle_definition_id'] as num?)?.toInt() ?? 0,
      companyId: (json['company_id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      prefix: json['prefix'] as String? ?? '',
      codeLength: (json['code_length'] as num?)?.toInt() ?? 0,
      startDate: _parseDate(json['start_date']),
      endDate: _parseDate(json['end_date']),
      triggerAmount: (json['trigger_amount'] as num?)?.toDouble() ?? 0,
      couponsPerTrigger: (json['coupons_per_trigger'] as num?)?.toInt() ?? 0,
      maxCouponsPerSale: (json['max_coupons_per_sale'] as num?)?.toInt(),
      defaultAutoFillCustomerData:
          json['default_auto_fill_customer_data'] as bool? ?? false,
      printAfterInvoice: json['print_after_invoice'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? false,
      issuedCoupons: (json['issued_coupons'] as num?)?.toInt() ?? 0,
      winnerCount: (json['winner_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class RaffleCouponDto {
  const RaffleCouponDto({
    required this.raffleCouponId,
    required this.raffleDefinitionId,
    required this.saleId,
    this.customerId,
    required this.couponCode,
    required this.status,
    required this.autoFilled,
    required this.printAfterInvoice,
    this.customerName,
    this.customerPhone,
    this.customerEmail,
    this.customerAddress,
    this.winnerName,
    this.winnerNotes,
    required this.issuedAt,
    this.winnerMarkedAt,
    this.raffleDefinitionName,
    this.saleNumber,
  });

  final int raffleCouponId;
  final int raffleDefinitionId;
  final int saleId;
  final int? customerId;
  final String couponCode;
  final String status;
  final bool autoFilled;
  final bool printAfterInvoice;
  final String? customerName;
  final String? customerPhone;
  final String? customerEmail;
  final String? customerAddress;
  final String? winnerName;
  final String? winnerNotes;
  final DateTime issuedAt;
  final DateTime? winnerMarkedAt;
  final String? raffleDefinitionName;
  final String? saleNumber;

  factory RaffleCouponDto.fromJson(Map<String, dynamic> json) {
    return RaffleCouponDto(
      raffleCouponId: (json['raffle_coupon_id'] as num?)?.toInt() ?? 0,
      raffleDefinitionId: (json['raffle_definition_id'] as num?)?.toInt() ?? 0,
      saleId: (json['sale_id'] as num?)?.toInt() ?? 0,
      customerId: (json['customer_id'] as num?)?.toInt(),
      couponCode: json['coupon_code'] as String? ?? '',
      status: json['status'] as String? ?? '',
      autoFilled: json['auto_filled'] as bool? ?? false,
      printAfterInvoice: json['print_after_invoice'] as bool? ?? false,
      customerName: json['customer_name'] as String?,
      customerPhone: json['customer_phone'] as String?,
      customerEmail: json['customer_email'] as String?,
      customerAddress: json['customer_address'] as String?,
      winnerName: json['winner_name'] as String?,
      winnerNotes: json['winner_notes'] as String?,
      issuedAt: _parseDate(json['issued_at']),
      winnerMarkedAt: json['winner_marked_at'] != null
          ? _parseDate(json['winner_marked_at'])
          : null,
      raffleDefinitionName: json['raffle_definition_name'] as String?,
      saleNumber: json['sale_number'] as String?,
    );
  }
}

class PromotionImportResultDto {
  const PromotionImportResultDto({
    required this.count,
    required this.created,
    required this.updated,
    required this.skipped,
    required this.errors,
  });

  final int count;
  final int created;
  final int updated;
  final int skipped;
  final List<String> errors;

  factory PromotionImportResultDto.fromJson(Map<String, dynamic> json) {
    final rawErrors = (json['errors'] as List<dynamic>? ?? const []);
    return PromotionImportResultDto(
      count: (json['count'] as num?)?.toInt() ?? 0,
      created: (json['created'] as num?)?.toInt() ?? 0,
      updated: (json['updated'] as num?)?.toInt() ?? 0,
      skipped: (json['skipped'] as num?)?.toInt() ?? 0,
      errors: rawErrors.map((item) {
        if (item is Map) {
          final row = item['row'];
          final column = item['column'];
          final message = item['message'];
          final parts = <String>[
            if (row != null && '$row'.isNotEmpty) 'Row $row',
            if (column != null && '$column'.isNotEmpty) '$column',
            if (message != null && '$message'.isNotEmpty) '$message',
          ];
          return parts.join(' • ');
        }
        return '$item';
      }).toList(growable: false),
    );
  }
}
