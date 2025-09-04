import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';

class CurrencyDto {
  final int currencyId;
  final String code;
  final String name;
  final String? symbol;

  CurrencyDto({required this.currencyId, required this.code, required this.name, this.symbol});

  factory CurrencyDto.fromJson(Map<String, dynamic> json) => CurrencyDto(
        currencyId: json['currency_id'] as int,
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? '',
        symbol: json['symbol'] as String?,
      );
}

class CurrencyRepository {
  CurrencyRepository(this._dio);
  final Dio _dio;

  Future<List<CurrencyDto>> getCurrencies() async {
    final res = await _dio.get('/currencies');
    final body = res.data;
    final list = body is Map<String, dynamic> ? (body['data'] as List<dynamic>) : (body as List<dynamic>);
    return list.map((e) => CurrencyDto.fromJson(e as Map<String, dynamic>)).toList();
  }
}

final currencyRepositoryProvider = Provider<CurrencyRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return CurrencyRepository(dio);
});

