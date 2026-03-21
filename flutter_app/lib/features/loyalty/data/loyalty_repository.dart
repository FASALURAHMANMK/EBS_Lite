import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';

class LoyaltySettingsDto {
  final double pointsPerCurrency;
  final double pointValue;
  final int minRedemptionPoints;
  final int minPointsReserve;
  final int pointsExpiryDays;
  final String redemptionType;

  LoyaltySettingsDto({
    required this.pointsPerCurrency,
    required this.pointValue,
    required this.minRedemptionPoints,
    required this.minPointsReserve,
    required this.pointsExpiryDays,
    required this.redemptionType,
  });

  factory LoyaltySettingsDto.fromJson(Map<String, dynamic> json) =>
      LoyaltySettingsDto(
        pointsPerCurrency:
            (json['points_per_currency'] as num?)?.toDouble() ?? 1,
        pointValue: (json['point_value'] as num?)?.toDouble() ?? 0.01,
        minRedemptionPoints:
            (json['min_redemption_points'] as num?)?.toInt() ?? 0,
        minPointsReserve: (json['min_points_reserve'] as num?)?.toInt() ?? 0,
        pointsExpiryDays: (json['points_expiry_days'] as num?)?.toInt() ?? 0,
        redemptionType:
            (json['redemption_type'] as String? ?? 'DISCOUNT').toUpperCase(),
      );
}

class LoyaltyGiftRedemptionItemDto {
  final int redemptionItemId;
  final int productId;
  final int? barcodeId;
  final String productName;
  final String? variantName;
  final double quantity;
  final double pointsUsed;
  final double valueRedeemed;

  const LoyaltyGiftRedemptionItemDto({
    required this.redemptionItemId,
    required this.productId,
    this.barcodeId,
    required this.productName,
    this.variantName,
    required this.quantity,
    required this.pointsUsed,
    required this.valueRedeemed,
  });

  factory LoyaltyGiftRedemptionItemDto.fromJson(Map<String, dynamic> json) =>
      LoyaltyGiftRedemptionItemDto(
        redemptionItemId: json['redemption_item_id'] as int? ?? 0,
        productId: json['product_id'] as int? ?? 0,
        barcodeId: json['barcode_id'] as int?,
        productName: json['product_name'] as String? ?? '',
        variantName: json['variant_name'] as String?,
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
        pointsUsed: (json['points_used'] as num?)?.toDouble() ?? 0,
        valueRedeemed: (json['value_redeemed'] as num?)?.toDouble() ?? 0,
      );
}

class LoyaltyRedemptionResultDto {
  final int redemptionId;
  final int customerId;
  final double pointsUsed;
  final double valueRedeemed;
  final double remainingPoints;
  final String redemptionType;
  final String message;
  final List<LoyaltyGiftRedemptionItemDto> items;

  const LoyaltyRedemptionResultDto({
    required this.redemptionId,
    required this.customerId,
    required this.pointsUsed,
    required this.valueRedeemed,
    required this.remainingPoints,
    required this.redemptionType,
    required this.message,
    required this.items,
  });

  factory LoyaltyRedemptionResultDto.fromJson(Map<String, dynamic> json) =>
      LoyaltyRedemptionResultDto(
        redemptionId: json['redemption_id'] as int? ?? 0,
        customerId: json['customer_id'] as int? ?? 0,
        pointsUsed: (json['points_used'] as num?)?.toDouble() ?? 0,
        valueRedeemed: (json['value_redeemed'] as num?)?.toDouble() ?? 0,
        remainingPoints: (json['remaining_points'] as num?)?.toDouble() ?? 0,
        redemptionType:
            (json['redemption_type'] as String? ?? 'DISCOUNT').toUpperCase(),
        message: json['message'] as String? ?? '',
        items: (json['items'] as List? ?? const [])
            .map((e) => LoyaltyGiftRedemptionItemDto.fromJson(
                e as Map<String, dynamic>))
            .toList(),
      );
}

class LoyaltyTierDto {
  final int tierId;
  final String name;
  final double minPoints;
  final double? pointsPerCurrency;
  final bool isActive;

  LoyaltyTierDto(
      {required this.tierId,
      required this.name,
      required this.minPoints,
      required this.isActive,
      this.pointsPerCurrency});

  factory LoyaltyTierDto.fromJson(Map<String, dynamic> json) => LoyaltyTierDto(
        tierId: json['tier_id'] as int,
        name: json['name'] as String? ?? '',
        minPoints: (json['min_points'] as num?)?.toDouble() ?? 0,
        pointsPerCurrency: (json['points_per_currency'] as num?)?.toDouble(),
        isActive: json['is_active'] as bool? ?? true,
      );
}

class LoyaltyRepository {
  LoyaltyRepository(this._dio);
  final Dio _dio;

  Future<LoyaltySettingsDto> getSettings() async {
    final res = await _dio.get('/loyalty/settings');
    final map = res.data is Map<String, dynamic> ? res.data['data'] : res.data;
    return LoyaltySettingsDto.fromJson(Map<String, dynamic>.from(map as Map));
  }

  Future<void> updateSettings(
      {double? pointsPerCurrency,
      double? pointValue,
      int? minRedemptionPoints,
      int? minPointsReserve,
      int? pointsExpiryDays,
      String? redemptionType}) async {
    final payload = <String, dynamic>{};
    if (pointsPerCurrency != null) {
      payload['points_per_currency'] = pointsPerCurrency;
    }
    if (pointValue != null) payload['point_value'] = pointValue;
    if (minRedemptionPoints != null) {
      payload['min_redemption_points'] = minRedemptionPoints;
    }
    if (minPointsReserve != null) {
      payload['min_points_reserve'] = minPointsReserve;
    }
    if (pointsExpiryDays != null) {
      payload['points_expiry_days'] = pointsExpiryDays;
    }
    if (redemptionType != null && redemptionType.trim().isNotEmpty) {
      payload['redemption_type'] = redemptionType.trim().toUpperCase();
    }
    await _dio.put('/loyalty/settings', data: payload);
  }

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

  Future<List<LoyaltyTierDto>> getTiers() async {
    final res = await _dio.get('/loyalty/tiers');
    final data = _extractList(res);
    return data
        .map((e) => LoyaltyTierDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<LoyaltyTierDto> createTier(
      {required String name,
      required double minPoints,
      double? pointsPerCurrency}) async {
    final data = {
      'name': name,
      'min_points': minPoints,
      if (pointsPerCurrency != null) 'points_per_currency': pointsPerCurrency
    };
    final res = await _dio.post('/loyalty/tiers', data: data);
    final body = res.data is Map<String, dynamic> ? res.data['data'] : res.data;
    return LoyaltyTierDto.fromJson(Map<String, dynamic>.from(body as Map));
  }

  Future<void> updateTier(
      {required int tierId,
      String? name,
      double? minPoints,
      double? pointsPerCurrency,
      bool? isActive}) async {
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (minPoints != null) payload['min_points'] = minPoints;
    if (pointsPerCurrency != null) {
      payload['points_per_currency'] = pointsPerCurrency;
    }
    if (isActive != null) payload['is_active'] = isActive;
    await _dio.put('/loyalty/tiers/$tierId', data: payload);
  }

  Future<void> deleteTier(int tierId) async {
    await _dio.delete('/loyalty/tiers/$tierId');
  }

  Future<LoyaltyRedemptionResultDto> redeemGift({
    required int customerId,
    required int locationId,
    required List<Map<String, dynamic>> items,
    String? notes,
    String? overridePassword,
  }) async {
    final res = await _dio.post(
      '/loyalty-redemptions',
      data: {
        'customer_id': customerId,
        'redemption_type': 'GIFT',
        'location_id': locationId,
        'items': items,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        if (overridePassword != null && overridePassword.trim().isNotEmpty)
          'override_password': overridePassword.trim(),
      },
    );
    final body = res.data is Map<String, dynamic> ? res.data['data'] : res.data;
    return LoyaltyRedemptionResultDto.fromJson(
      Map<String, dynamic>.from(body as Map),
    );
  }
}

final loyaltyRepositoryProvider = Provider<LoyaltyRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return LoyaltyRepository(dio);
});
