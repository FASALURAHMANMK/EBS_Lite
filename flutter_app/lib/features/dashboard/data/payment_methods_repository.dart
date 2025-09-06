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

  // Per-method currencies mapping: grouped by methodId -> [{currency_id, rate}]
  Future<Map<int, List<Map<String, dynamic>>>> getMethodCurrencies() async {
    final res = await _dio.get('/settings/payment-methods/currencies');
    final body = res.data;
    final list = body is Map<String, dynamic> ? (body['data'] as List<dynamic>? ?? const []) : (body as List<dynamic>? ?? const []);
    final grouped = <int, List<Map<String, dynamic>>>{};
    for (final row in list) {
      final m = row as Map<String, dynamic>;
      final mid = m['method_id'] as int?;
      final cid = m['currency_id'] as int?;
      final rate = (m['exchange_rate'] as num?)?.toDouble();
      if (mid == null || cid == null) continue;
      grouped.putIfAbsent(mid, () => []);
      grouped[mid]!.add({'currency_id': cid, 'rate': rate ?? 1.0});
    }
    return grouped;
  }

  // Update currencies for a single method
  Future<void> setMethodCurrenciesForMethod(int methodId, List<Map<String, dynamic>> currencies) async {
    final items = currencies
        .map((e) => {
              'currency_id': e['currency_id'],
              'exchange_rate': e['rate'],
            })
        .toList();
    await _dio.put('/settings/payment-methods/$methodId/currencies', data: {
      'currencies': items,
    });
  }
}

final paymentMethodsRepositoryProvider = Provider<PaymentMethodsRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return PaymentMethodsRepository(dio);
});
