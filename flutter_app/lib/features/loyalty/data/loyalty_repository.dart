import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';

class LoyaltySettingsDto {
  final double pointsPerCurrency;
  final double pointValue;
  final int minRedemptionPoints;
  final int minPointsReserve;
  final int pointsExpiryDays;

  LoyaltySettingsDto({
    required this.pointsPerCurrency,
    required this.pointValue,
    required this.minRedemptionPoints,
    required this.minPointsReserve,
    required this.pointsExpiryDays,
  });

  factory LoyaltySettingsDto.fromJson(Map<String, dynamic> json) => LoyaltySettingsDto(
        pointsPerCurrency: (json['points_per_currency'] as num?)?.toDouble() ?? 1,
        pointValue: (json['point_value'] as num?)?.toDouble() ?? 0.01,
        minRedemptionPoints: (json['min_redemption_points'] as num?)?.toInt() ?? 0,
        minPointsReserve: (json['min_points_reserve'] as num?)?.toInt() ?? 0,
        pointsExpiryDays: (json['points_expiry_days'] as num?)?.toInt() ?? 0,
      );
}

class LoyaltyTierDto {
  final int tierId;
  final String name;
  final double minPoints;
  final double? pointsPerCurrency;
  final bool isActive;

  LoyaltyTierDto({required this.tierId, required this.name, required this.minPoints, required this.isActive, this.pointsPerCurrency});

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

  Future<void> updateSettings({double? pointsPerCurrency, double? pointValue, int? minRedemptionPoints, int? minPointsReserve, int? pointsExpiryDays}) async {
    final payload = <String, dynamic>{};
    if (pointsPerCurrency != null) payload['points_per_currency'] = pointsPerCurrency;
    if (pointValue != null) payload['point_value'] = pointValue;
    if (minRedemptionPoints != null) payload['min_redemption_points'] = minRedemptionPoints;
    if (minPointsReserve != null) payload['min_points_reserve'] = minPointsReserve;
    if (pointsExpiryDays != null) payload['points_expiry_days'] = pointsExpiryDays;
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
    return data.map((e) => LoyaltyTierDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<LoyaltyTierDto> createTier({required String name, required double minPoints, double? pointsPerCurrency}) async {
    final data = {'name': name, 'min_points': minPoints, if (pointsPerCurrency != null) 'points_per_currency': pointsPerCurrency};
    final res = await _dio.post('/loyalty/tiers', data: data);
    final body = res.data is Map<String, dynamic> ? res.data['data'] : res.data;
    return LoyaltyTierDto.fromJson(Map<String, dynamic>.from(body as Map));
  }

  Future<void> updateTier({required int tierId, String? name, double? minPoints, double? pointsPerCurrency, bool? isActive}) async {
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (minPoints != null) payload['min_points'] = minPoints;
    if (pointsPerCurrency != null) payload['points_per_currency'] = pointsPerCurrency;
    if (isActive != null) payload['is_active'] = isActive;
    await _dio.put('/loyalty/tiers/$tierId', data: payload);
  }

  Future<void> deleteTier(int tierId) async {
    await _dio.delete('/loyalty/tiers/$tierId');
  }
}

final loyaltyRepositoryProvider = Provider<LoyaltyRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return LoyaltyRepository(dio);
});
