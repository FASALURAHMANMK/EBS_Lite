import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';

class InvoiceTemplateDto {
  final int templateId;
  final int companyId;
  final String name;
  final String templateType;
  final dynamic layout;
  final String? primaryLanguage;
  final String? secondaryLanguage;
  final bool isDefault;
  final bool isActive;
  final DateTime? createdAt;

  const InvoiceTemplateDto({
    required this.templateId,
    required this.companyId,
    required this.name,
    required this.templateType,
    required this.layout,
    required this.primaryLanguage,
    required this.secondaryLanguage,
    required this.isDefault,
    required this.isActive,
    required this.createdAt,
  });

  factory InvoiceTemplateDto.fromJson(Map<String, dynamic> json) =>
      InvoiceTemplateDto(
        templateId: (json['template_id'] as num?)?.toInt() ?? 0,
        companyId: (json['company_id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '',
        templateType: json['template_type'] as String? ?? '',
        layout: json['layout'],
        primaryLanguage: json['primary_language'] as String?,
        secondaryLanguage: json['secondary_language'] as String?,
        isDefault: json['is_default'] as bool? ?? false,
        isActive: json['is_active'] as bool? ?? true,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      );
}

class InvoiceTemplatesRepository {
  InvoiceTemplatesRepository(this._dio);
  final Dio _dio;

  List<dynamic> _extractList(dynamic body) {
    if (body is List) return body;
    if (body is Map) {
      final value = body['data'];
      if (value is List) return value;
      return const [];
    }
    return const [];
  }

  Map<String, dynamic> _extractDataMap(dynamic body) {
    if (body is Map<String, dynamic>) {
      final d = body['data'];
      if (d is Map<String, dynamic>) return d;
    }
    return const {};
  }

  Future<List<InvoiceTemplateDto>> list() async {
    final res = await _dio.get('/invoice-templates');
    return _extractList(res.data)
        .map((e) => InvoiceTemplateDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<InvoiceTemplateDto> getById(int id) async {
    final res = await _dio.get('/invoice-templates/$id');
    return InvoiceTemplateDto.fromJson(_extractDataMap(res.data));
  }

  Future<InvoiceTemplateDto> create({
    required int companyId,
    required String name,
    required String templateType,
    required dynamic layout,
    String? primaryLanguage,
    String? secondaryLanguage,
    bool isDefault = false,
    bool isActive = true,
  }) async {
    final res = await _dio.post('/invoice-templates', data: {
      'company_id': companyId,
      'name': name,
      'template_type': templateType,
      'layout': layout,
      if (primaryLanguage != null) 'primary_language': primaryLanguage,
      if (secondaryLanguage != null) 'secondary_language': secondaryLanguage,
      'is_default': isDefault,
      'is_active': isActive,
    });
    return InvoiceTemplateDto.fromJson(_extractDataMap(res.data));
  }

  Future<void> update({
    required int templateId,
    String? name,
    String? templateType,
    dynamic layout,
    String? primaryLanguage,
    String? secondaryLanguage,
    bool? isDefault,
    bool? isActive,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (templateType != null) payload['template_type'] = templateType;
    if (layout != null) payload['layout'] = layout;
    if (primaryLanguage != null) payload['primary_language'] = primaryLanguage;
    if (secondaryLanguage != null) {
      payload['secondary_language'] = secondaryLanguage;
    }
    if (isDefault != null) payload['is_default'] = isDefault;
    if (isActive != null) payload['is_active'] = isActive;
    await _dio.put('/invoice-templates/$templateId', data: payload);
  }

  Future<void> delete(int templateId) async {
    await _dio.delete('/invoice-templates/$templateId');
  }

  dynamic decodeLayoutJson(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return {};
    return jsonDecode(trimmed);
  }

  String encodeLayoutJson(dynamic layout) {
    try {
      return const JsonEncoder.withIndent('  ').convert(layout);
    } catch (_) {
      return '{}';
    }
  }
}

final invoiceTemplatesRepositoryProvider =
    Provider<InvoiceTemplatesRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return InvoiceTemplatesRepository(dio);
});
