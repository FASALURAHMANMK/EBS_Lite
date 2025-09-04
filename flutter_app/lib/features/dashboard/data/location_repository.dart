import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import 'models.dart';

class LocationRepository {
  LocationRepository(this._dio);

  final Dio _dio;

  Future<List<Location>> fetchLocations(int companyId) async {
    final res = await _dio.get(
      '/locations',
      queryParameters: {'company_id': companyId},
    );
    final data = res.data['data'] as List<dynamic>;
    return data
        .map((e) => Location.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Location> createLocation({
    required int companyId,
    required String name,
    String? address,
    String? phone,
  }) async {
    final res = await _dio.post('/locations', data: {
      'company_id': companyId,
      'name': name,
      if (address != null) 'address': address,
      if (phone != null) 'phone': phone,
    });
    final data = res.data['data'] as Map<String, dynamic>;
    return Location.fromJson(data);
  }

  Future<void> updateLocation({
    required int locationId,
    String? name,
    String? address,
    String? phone,
    bool? isActive,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (address != null) body['address'] = address;
    if (phone != null) body['phone'] = phone;
    if (isActive != null) body['is_active'] = isActive;
    await _dio.put('/locations/$locationId', data: body);
  }

  Future<void> deleteLocation(int locationId) async {
    await _dio.delete('/locations/$locationId');
  }
}

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return LocationRepository(dio);
});
