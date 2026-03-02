import 'dart:convert';

class PromotionDto {
  PromotionDto({
    required this.promotionId,
    required this.companyId,
    required this.name,
    this.description,
    this.discountType,
    this.value,
    this.minAmount,
    required this.startDate,
    required this.endDate,
    this.applicableTo,
    this.conditions,
    required this.isActive,
  });

  final int promotionId;
  final int companyId;
  final String name;
  final String? description;
  final String? discountType;
  final double? value;
  final double? minAmount;
  final DateTime startDate;
  final DateTime endDate;
  final String? applicableTo;
  final Map<String, dynamic>? conditions;
  final bool isActive;

  factory PromotionDto.fromJson(Map<String, dynamic> json) {
    return PromotionDto(
      promotionId: (json['promotion_id'] as num?)?.toInt() ?? 0,
      companyId: (json['company_id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? '',
      description: json['description'] as String?,
      discountType: json['discount_type'] as String?,
      value: (json['value'] as num?)?.toDouble(),
      minAmount: (json['min_amount'] as num?)?.toDouble(),
      startDate: _parseDate(json['start_date']),
      endDate: _parseDate(json['end_date']),
      applicableTo: json['applicable_to'] as String?,
      conditions: _parseConditions(json['conditions']),
      isActive: json['is_active'] as bool? ?? false,
    );
  }

  static DateTime _parseDate(dynamic v) {
    if (v is DateTime) return v;
    if (v is String) {
      return DateTime.tryParse(v) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static Map<String, dynamic>? _parseConditions(dynamic v) {
    if (v == null) return null;
    if (v is Map) {
      return Map<String, dynamic>.from(v);
    }
    if (v is String && v.isNotEmpty) {
      try {
        final decoded = jsonDecode(v);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }
    return null;
  }
}
