import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';

class TaxComponentDto {
  final int? componentId;
  final String name;
  final double percentage;
  final int sortOrder;

  const TaxComponentDto({
    this.componentId,
    required this.name,
    required this.percentage,
    this.sortOrder = 0,
  });

  factory TaxComponentDto.fromJson(Map<String, dynamic> json) =>
      TaxComponentDto(
        componentId: (json['component_id'] as num?)?.toInt(),
        name: json['name'] as String? ?? '',
        percentage: (json['percentage'] as num?)?.toDouble() ?? 0,
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'percentage': percentage,
        'sort_order': sortOrder,
      };
}

class TaxDto {
  final int taxId;
  final String name;
  final double percentage;
  final bool isCompound;
  final bool isActive;
  final List<TaxComponentDto> components;

  const TaxDto({
    required this.taxId,
    required this.name,
    required this.percentage,
    required this.isCompound,
    required this.isActive,
    this.components = const [],
  });

  factory TaxDto.fromJson(Map<String, dynamic> json) => TaxDto(
        taxId: json['tax_id'] as int,
        name: json['name'] as String? ?? '',
        percentage: (json['percentage'] as num?)?.toDouble() ?? 0,
        isCompound: json['is_compound'] as bool? ?? false,
        isActive: json['is_active'] as bool? ?? true,
        components: (json['components'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => TaxComponentDto.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false),
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
    double? percentage,
    List<TaxComponentDto>? components,
    bool isCompound = false,
    bool isActive = true,
  }) async {
    final comps = components ?? const [];
    final hasComponents =
        comps.where((c) => c.name.trim().isNotEmpty).isNotEmpty;
    final totalFromComponents = comps.fold<double>(
        0, (sum, c) => sum + (c.percentage.isFinite ? c.percentage : 0));
    final payload = <String, dynamic>{
      'name': name,
      if (hasComponents) 'components': comps.map((c) => c.toJson()).toList(),
      // Keep sending percentage for backward compatibility; backend may recompute from components.
      if (percentage != null || hasComponents)
        'percentage': (percentage ?? totalFromComponents),
      'is_compound': isCompound,
      'is_active': isActive,
    };
    final res = await _dio.post('/taxes', data: {
      ...payload,
    });
    final body = res.data is Map<String, dynamic> ? res.data['data'] : res.data;
    return TaxDto.fromJson(body as Map<String, dynamic>);
  }

  Future<void> updateTax({
    required int taxId,
    String? name,
    double? percentage,
    List<TaxComponentDto>? components,
    bool? isCompound,
    bool? isActive,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (percentage != null) payload['percentage'] = percentage;
    if (components != null) {
      payload['components'] = components.map((c) => c.toJson()).toList();
      // If caller didn't specify percentage, keep it aligned with component sum for older backends.
      if (!payload.containsKey('percentage')) {
        payload['percentage'] =
            components.fold<double>(0, (sum, c) => sum + c.percentage);
      }
    }
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
