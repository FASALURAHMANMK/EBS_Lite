import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';

class TaxDto {
  final int taxId;
  final String name;
  final double percentage;
  final bool isCompound;
  final bool isActive;

  const TaxDto({
    required this.taxId,
    required this.name,
    required this.percentage,
    required this.isCompound,
    required this.isActive,
  });

  factory TaxDto.fromJson(Map<String, dynamic> json) => TaxDto(
        taxId: json['tax_id'] as int,
        name: json['name'] as String? ?? '',
        percentage: (json['percentage'] as num?)?.toDouble() ?? 0,
        isCompound: json['is_compound'] as bool? ?? false,
        isActive: json['is_active'] as bool? ?? true,
      );
}

class TaxesRepository {
  TaxesRepository(this._dio);
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

  Future<List<TaxDto>> getTaxes() async {
    final res = await _dio.get('/taxes');
    final data = _extractList(res);
    return data.map((e) => TaxDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<TaxDto> createTax({
    required String name,
    required double percentage,
    bool isCompound = false,
    bool isActive = true,
  }) async {
    final res = await _dio.post('/taxes', data: {
      'name': name,
      'percentage': percentage,
      'is_compound': isCompound,
      'is_active': isActive,
    });
    final body = res.data is Map<String, dynamic> ? res.data['data'] : res.data;
    return TaxDto.fromJson(body as Map<String, dynamic>);
  }

  Future<void> updateTax({
    required int taxId,
    String? name,
    double? percentage,
    bool? isCompound,
    bool? isActive,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (percentage != null) payload['percentage'] = percentage;
    if (isCompound != null) payload['is_compound'] = isCompound;
    if (isActive != null) payload['is_active'] = isActive;
    await _dio.put('/taxes/$taxId', data: payload);
  }

  Future<void> deleteTax(int taxId) async {
    await _dio.delete('/taxes/$taxId');
  }
}

final taxesRepositoryProvider = Provider<TaxesRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return TaxesRepository(dio);
});

