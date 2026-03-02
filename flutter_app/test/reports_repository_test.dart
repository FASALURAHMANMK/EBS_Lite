import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ebs_lite/features/reports/data/reports_repository.dart';

class _RecordingAdapter implements HttpClientAdapter {
  RequestOptions? lastOptions;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future? cancelFuture,
  ) async {
    lastOptions = options;

    final body = jsonEncode({
      'data': [
        {'ok': true}
      ],
    });

    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json; charset=utf-8'],
      },
    );
  }
}

void main() {
  test('ReportsRepository.fetchReport calls a concrete report endpoint',
      () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://example.test'));
    final adapter = _RecordingAdapter();
    dio.httpClientAdapter = adapter;

    final repo = ReportsRepository(dio);
    final res = await repo.fetchReport(
      '/reports/sales-summary',
      queryParameters: {'group_by': 'day'},
    );

    expect(adapter.lastOptions?.path, '/reports/sales-summary');
    expect(adapter.lastOptions?.queryParameters['group_by'], 'day');
    expect(res, isA<List>());
  });
}
