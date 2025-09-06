import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';

class PaymentMethodDto {
  final int methodId;
  final String name;
  final String type; // CASH, CARD, ONLINE, UPI, CHEQUE, CREDIT, etc
  final bool isActive;

  PaymentMethodDto({
    required this.methodId,
    required this.name,
    required this.type,
    required this.isActive,
  });

  factory PaymentMethodDto.fromJson(Map<String, dynamic> json) => PaymentMethodDto(
        methodId: json['method_id'] as int,
        name: json['name'] as String? ?? '',
        type: json['type'] as String? ?? 'OTHER',
        isActive: json['is_active'] as bool? ?? true,
      );
}

class PaymentMethodsRepository {
  PaymentMethodsRepository(this._dio);
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

  Future<List<PaymentMethodDto>> getMethods() async {
    final res = await _dio.get('/settings/payment-methods');
    final data = _extractList(res);
    return data.map((e) => PaymentMethodDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<PaymentMethodDto> createMethod({
    required String name,
    required String type,
    bool isActive = true,
  }) async {
    final res = await _dio.post('/settings/payment-methods', data: {
      'name': name,
      'type': type,
      'is_active': isActive,
    });
    final body = res.data is Map<String, dynamic> ? res.data['data'] : res.data;
    return PaymentMethodDto.fromJson(body as Map<String, dynamic>);
  }

  Future<void> updateMethod({
    required int id,
    required String name,
    required String type,
    required bool isActive,
  }) async {
    await _dio.put('/settings/payment-methods/$id', data: {
      'name': name,
      'type': type,
      'is_active': isActive,
    });
  }

  Future<void> deleteMethod(int id) async {
    await _dio.delete('/settings/payment-methods/$id');
  }

  // Settings mapping for per-method currencies: { method_id: [{currency_id, rate?}] }
  Future<Map<int, List<Map<String, dynamic>>>> getMethodCurrencies() async {
    final res = await _dio.get('/settings');
    final body = res.data;
    final data = body is Map<String, dynamic> ? body['data'] : body;
    if (data is Map<String, dynamic>) {
      final raw = data['payment_method_currencies'];
      if (raw is Map<String, dynamic>) {
        final map = <int, List<Map<String, dynamic>>>{};
        raw.forEach((k, v) {
          final id = int.tryParse(k) ?? -1;
          if (id > 0 && v is List) {
            map[id] = v.cast<Map<String, dynamic>>();
          }
        });
        return map;
      }
    }
    return {};
  }

  Future<void> setMethodCurrencies(Map<int, List<Map<String, dynamic>>> mapping) async {
    final payload = <String, dynamic>{};
    mapping.forEach((k, v) => payload[k.toString()] = v);
    await _dio.put('/settings', data: {
      'settings': {
        'payment_method_currencies': payload,
      }
    });
  }
}

final paymentMethodsRepositoryProvider = Provider<PaymentMethodsRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return PaymentMethodsRepository(dio);
});

