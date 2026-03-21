import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import 'warranty_models.dart';

class WarrantyRepository {
  WarrantyRepository(this._dio);

  final Dio _dio;

  dynamic _extractData(Response res) {
    final body = res.data;
    if (body is Map<String, dynamic> && body['data'] != null) {
      return body['data'];
    }
    return body;
  }

  List<dynamic> _extractList(Response res) {
    final data = _extractData(res);
    if (data is List) return data;
    return const [];
  }

  Future<PrepareWarrantyResponseDto> prepareWarranty(String saleNumber) async {
    final res = await _dio.get(
      '/warranties/prepare',
      queryParameters: {'sale_number': saleNumber.trim()},
    );
    final body = _extractData(res) as Map<String, dynamic>;
    return PrepareWarrantyResponseDto.fromJson(body);
  }

  Future<WarrantyRegistrationDto> createWarranty(
    CreateWarrantyPayload payload,
  ) async {
    final res = await _dio.post('/warranties', data: payload.toJson());
    final body = _extractData(res) as Map<String, dynamic>;
    return WarrantyRegistrationDto.fromJson(body);
  }

  Future<List<WarrantyRegistrationDto>> searchWarranties({
    String? saleNumber,
    String? phone,
  }) async {
    final qp = <String, dynamic>{};
    if (saleNumber != null && saleNumber.trim().isNotEmpty) {
      qp['sale_number'] = saleNumber.trim();
    }
    if (phone != null && phone.trim().isNotEmpty) {
      qp['phone'] = phone.trim();
    }
    final res = await _dio.get(
      '/warranties/search',
      queryParameters: qp.isEmpty ? null : qp,
    );
    return _extractList(res)
        .map((e) => WarrantyRegistrationDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<WarrantyRegistrationDto> getWarranty(int warrantyId) async {
    final res = await _dio.get('/warranties/$warrantyId');
    final body = _extractData(res) as Map<String, dynamic>;
    return WarrantyRegistrationDto.fromJson(body);
  }

  Future<WarrantyCardDataDto> getWarrantyCardData(int warrantyId) async {
    final res = await _dio.get('/warranties/$warrantyId/card');
    final body = _extractData(res) as Map<String, dynamic>;
    return WarrantyCardDataDto.fromJson(body);
  }
}

final warrantyRepositoryProvider = Provider<WarrantyRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return WarrantyRepository(dio);
});
