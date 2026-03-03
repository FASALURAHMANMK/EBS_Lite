import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';

class PrinterProfileDto {
  final int printerId;
  final int? locationId;
  final String name;
  final String printerType;
  final String? paperSize;
  final Map<String, dynamic>? connectivity;
  final bool isDefault;
  final bool isActive;

  const PrinterProfileDto({
    required this.printerId,
    required this.locationId,
    required this.name,
    required this.printerType,
    required this.paperSize,
    required this.connectivity,
    required this.isDefault,
    required this.isActive,
  });

  factory PrinterProfileDto.fromJson(Map<String, dynamic> json) =>
      PrinterProfileDto(
        printerId: (json['printer_id'] as num?)?.toInt() ?? 0,
        locationId: (json['location_id'] as num?)?.toInt(),
        name: json['name'] as String? ?? '',
        printerType: json['printer_type'] as String? ?? '',
        paperSize: json['paper_size'] as String?,
        connectivity: (json['connectivity'] is Map<String, dynamic>)
            ? (json['connectivity'] as Map<String, dynamic>)
            : null,
        isDefault: json['is_default'] as bool? ?? false,
        isActive: json['is_active'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'printer_type': printerType,
        if (locationId != null) 'location_id': locationId,
        if (paperSize != null) 'paper_size': paperSize,
        if (connectivity != null) 'connectivity': connectivity,
        'is_default': isDefault,
        'is_active': isActive,
      };
}

class PrinterProfilesRepository {
  PrinterProfilesRepository(this._dio);
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

  Future<List<PrinterProfileDto>> list() async {
    final res = await _dio.get('/settings/printer');
    return _extractList(res.data)
        .map((e) => PrinterProfileDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PrinterProfileDto> create(PrinterProfileDto profile) async {
    final res = await _dio.post('/settings/printer', data: profile.toJson());
    return PrinterProfileDto.fromJson(_extractDataMap(res.data));
  }

  Future<void> update(PrinterProfileDto profile) async {
    await _dio.put('/settings/printer/${profile.printerId}',
        data: profile.toJson());
  }

  Future<void> delete(int printerId) async {
    await _dio.delete('/settings/printer/$printerId');
  }

  Map<String, dynamic> decodeConnectivity(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return {};
    final decoded = jsonDecode(trimmed);
    if (decoded is Map<String, dynamic>) return decoded;
    throw const FormatException('Connectivity JSON must be an object');
  }

  String encodeConnectivity(Map<String, dynamic>? conn) {
    try {
      return const JsonEncoder.withIndent('  ').convert(conn ?? {});
    } catch (_) {
      return '{}';
    }
  }
}

final printerProfilesRepositoryProvider =
    Provider<PrinterProfilesRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return PrinterProfilesRepository(dio);
});
