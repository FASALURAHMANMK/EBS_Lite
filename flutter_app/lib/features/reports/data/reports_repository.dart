import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/file_transfer.dart';

class ReportsRepository {
  ReportsRepository(this._dio);

  final Dio _dio;

  Future<dynamic> fetchReport(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final res = await _getReport(
      endpoint,
      queryParameters: queryParameters,
    );
    return _extractData(res.data);
  }

  Future<void> exportReport(
    String endpoint, {
    required String format,
    Map<String, dynamic>? queryParameters,
    String? shareTitle,
  }) async {
    final qp = <String, dynamic>{
      if (queryParameters != null) ...queryParameters,
      'format': format,
    };

    final ext = format == 'excel' ? 'xlsx' : 'pdf';
    final filename = 'report-${_endpointSlug(endpoint)}.$ext';
    final bytes = await FileTransfer.downloadBytes(
      _dio,
      endpoint,
      queryParameters: qp,
    );
    final filePath = await FileTransfer.saveToTemp(bytes, filename);
    final mimeType = FileTransfer.guessMimeTypeFromFilename(filename) ??
        'application/octet-stream';

    await FileTransfer.shareTempFile(
      filePath: filePath,
      filename: filename,
      mimeType: mimeType,
      subject: shareTitle ?? 'Report ${_endpointSlug(endpoint)}',
      text: 'Please find the attached report.',
    );
  }

  Future<Uint8List> downloadReportBytes(
    String endpoint, {
    required String format,
    Map<String, dynamic>? queryParameters,
  }) async {
    final qp = <String, dynamic>{
      if (queryParameters != null) ...queryParameters,
      'format': format,
    };
    return FileTransfer.downloadBytes(
      _dio,
      endpoint,
      queryParameters: qp,
    );
  }

  Future<Response<dynamic>> _getReport(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    switch (endpoint) {
      case '/reports/sales-summary':
        return _dio.get(
          '/reports/sales-summary',
          queryParameters: queryParameters,
          options: options,
        );
      case '/reports/top-products':
        return _dio.get(
          '/reports/top-products',
          queryParameters: queryParameters,
          options: options,
        );
      case '/reports/customer-balances':
        return _dio.get(
          '/reports/customer-balances',
          queryParameters: queryParameters,
          options: options,
        );
      case '/reports/tax':
        return _dio.get(
          '/reports/tax',
          queryParameters: queryParameters,
          options: options,
        );
      case '/reports/expenses-summary':
        return _dio.get(
          '/reports/expenses-summary',
          queryParameters: queryParameters,
          options: options,
        );
      case '/reports/purchase-vs-returns':
        return _dio.get(
          '/reports/purchase-vs-returns',
          queryParameters: queryParameters,
          options: options,
        );
      case '/reports/supplier':
        return _dio.get(
          '/reports/supplier',
          queryParameters: queryParameters,
          options: options,
        );
      case '/reports/daily-cash':
        return _dio.get(
          '/reports/daily-cash',
          queryParameters: queryParameters,
          options: options,
        );
      case '/reports/income-expense':
        return _dio.get(
          '/reports/income-expense',
          queryParameters: queryParameters,
          options: options,
        );
      case '/reports/general-ledger':
        return _dio.get(
          '/reports/general-ledger',
          queryParameters: queryParameters,
          options: options,
        );
      case '/reports/trial-balance':
        return _dio.get(
          '/reports/trial-balance',
          queryParameters: queryParameters,
          options: options,
        );
      case '/reports/profit-loss':
        return _dio.get(
          '/reports/profit-loss',
          queryParameters: queryParameters,
          options: options,
        );
      case '/reports/balance-sheet':
        return _dio.get(
          '/reports/balance-sheet',
          queryParameters: queryParameters,
          options: options,
        );
      case '/reports/outstanding':
        return _dio.get(
          '/reports/outstanding',
          queryParameters: queryParameters,
          options: options,
        );
      case '/reports/top-performers':
        return _dio.get(
          '/reports/top-performers',
          queryParameters: queryParameters,
          options: options,
        );
      case '/reports/stock-summary':
        return _dio.get(
          '/reports/stock-summary',
          queryParameters: queryParameters,
          options: options,
        );
      case '/reports/item-movement':
        return _dio.get(
          '/reports/item-movement',
          queryParameters: queryParameters,
          options: options,
        );
      case '/reports/valuation':
        return _dio.get(
          '/reports/valuation',
          queryParameters: queryParameters,
          options: options,
        );
      default:
        return _dio.get(
          endpoint,
          queryParameters: queryParameters,
          options: options,
        );
    }
  }

  String _endpointSlug(String endpoint) {
    final parts =
        endpoint.split('/').where((p) => p.trim().isNotEmpty).toList();
    if (parts.isEmpty) return 'report';
    return parts.last;
  }

  dynamic _extractData(dynamic body) {
    if (body is Map<String, dynamic>) {
      if (body.containsKey('data')) return body['data'];
    }
    return body;
  }
}

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return ReportsRepository(dio);
});
