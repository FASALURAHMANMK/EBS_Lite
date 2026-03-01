import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/api_client.dart';

class ReportsRepository {
  ReportsRepository(this._dio);

  final Dio _dio;

  Future<dynamic> fetchReport(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final res = await _dio.get(
      '/reports/$endpoint',
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
    final res = await _dio.get(
      '/reports/$endpoint',
      queryParameters: qp,
      options: Options(responseType: ResponseType.bytes),
    );

    final contentType = _getContentType(res);
    final bytes = _normalizeBytes(res.data);

    if (contentType.contains('application/json')) {
      final text = utf8.decode(bytes, allowMalformed: true);
      throw Exception(_extractErrorMessage(text));
    }

    final ext = format == 'excel' ? 'xlsx' : 'pdf';
    final filename = 'report-$endpoint.$ext';
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);

    await Share.shareXFiles(
      [XFile(file.path, name: filename, mimeType: contentType)],
      subject: shareTitle ?? 'Report $endpoint',
      text: 'Please find the attached report.',
    );
  }

  String _getContentType(Response res) {
    final header =
        res.headers.value('content-type')?.toLowerCase() ?? '';
    if (header.isNotEmpty) return header;
    return 'application/octet-stream';
  }

  Uint8List _normalizeBytes(dynamic data) {
    if (data is Uint8List) return data;
    if (data is List<int>) return Uint8List.fromList(data);
    if (data is String) return Uint8List.fromList(utf8.encode(data));
    return Uint8List(0);
  }

  dynamic _extractData(dynamic body) {
    if (body is Map<String, dynamic>) {
      if (body.containsKey('data')) return body['data'];
    }
    return body;
  }

  String _extractErrorMessage(String text) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) {
        if (decoded['error'] is String) return decoded['error'] as String;
        if (decoded['message'] is String) return decoded['message'] as String;
      }
    } catch (_) {}
    return text.isEmpty ? 'Export failed' : text;
  }
}

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return ReportsRepository(dio);
});
