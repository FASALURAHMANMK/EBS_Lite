import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../auth/data/models.dart';

class CompanyRepository {
  CompanyRepository(this._dio);
  final Dio _dio;

  Future<List<Company>> getCompanies() async {
    final res = await _dio.get('/companies');
    final body = res.data;
    final list = body is Map<String, dynamic> ? (body['data'] as List<dynamic>) : (body as List<dynamic>);
    return list.map((e) => Company.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> updateCompany(int companyId, {
    String? name,
    String? address,
    String? phone,
    String? email,
    String? taxNumber,
    int? currencyId,
    String? logo,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (address != null) body['address'] = address;
    if (phone != null) body['phone'] = phone;
    if (email != null) body['email'] = email;
    if (taxNumber != null) body['tax_number'] = taxNumber;
    if (currencyId != null) body['currency_id'] = currencyId;
    if (logo != null) body['logo'] = logo;
    await _dio.put('/companies/$companyId', data: body);
  }

  Future<String> uploadLogo(int companyId, String filePath, String fileName) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    final res = await _dio.post('/companies/$companyId/logo', data: form);
    final data = res.data is Map<String, dynamic> ? (res.data['data'] as Map<String, dynamic>) : res.data as Map<String, dynamic>;
    return data['logo'] as String;
  }
}

final companyRepositoryProvider = Provider<CompanyRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return CompanyRepository(dio);
});

