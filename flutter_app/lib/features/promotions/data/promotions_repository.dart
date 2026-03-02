import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import 'models.dart';

class PromotionsRepository {
  PromotionsRepository(this._dio);

  final Dio _dio;

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

  Future<List<PromotionDto>> getPromotions({bool activeOnly = false}) async {
    final res = await _dio.get(
      '/promotions',
      queryParameters: activeOnly ? const {'active': 'true'} : null,
    );
    final data = _extractList(res);
    return data
        .map((e) => PromotionDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PromotionDto> createPromotion({
    required String name,
    String? description,
    String? discountType,
    double? value,
    double? minAmount,
    required DateTime startDate,
    required DateTime endDate,
    String? applicableTo,
    Map<String, dynamic>? conditions,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      if (description != null && description.isNotEmpty)
        'description': description,
      if (discountType != null && discountType.isNotEmpty)
        'discount_type': discountType,
      if (value != null) 'value': value,
      if (minAmount != null) 'min_amount': minAmount,
      'start_date': _fmtDate(startDate),
      'end_date': _fmtDate(endDate),
      if (applicableTo != null && applicableTo.isNotEmpty)
        'applicable_to': applicableTo,
      if (conditions != null && conditions.isNotEmpty) 'conditions': conditions,
    };
    final res = await _dio.post('/promotions', data: body);
    final map = res.data is Map<String, dynamic> ? res.data['data'] : res.data;
    return PromotionDto.fromJson(map as Map<String, dynamic>);
  }

  Future<void> updatePromotion(
    int id, {
    String? name,
    String? description,
    String? discountType,
    double? value,
    double? minAmount,
    DateTime? startDate,
    DateTime? endDate,
    String? applicableTo,
    Map<String, dynamic>? conditions,
    bool? isActive,
  }) async {
    final body = <String, dynamic>{
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (discountType != null) 'discount_type': discountType,
      if (value != null) 'value': value,
      if (minAmount != null) 'min_amount': minAmount,
      if (startDate != null) 'start_date': _fmtDate(startDate),
      if (endDate != null) 'end_date': _fmtDate(endDate),
      if (applicableTo != null) 'applicable_to': applicableTo,
      if (conditions != null) 'conditions': conditions,
      if (isActive != null) 'is_active': isActive,
    };
    await _dio.put('/promotions/$id', data: body);
  }

  Future<void> deletePromotion(int id) async {
    await _dio.delete('/promotions/$id');
  }

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

final promotionsRepositoryProvider = Provider<PromotionsRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return PromotionsRepository(dio);
});
