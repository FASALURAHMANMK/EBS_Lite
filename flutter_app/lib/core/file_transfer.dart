import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class FileTransfer {
  static Future<Uint8List> downloadBytes(
    Dio dio,
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    final res = await dio.get(
      path,
      queryParameters: queryParameters,
      options: (options ?? Options()).copyWith(
        responseType: ResponseType.bytes,
        validateStatus: (_) => true,
      ),
    );

    final status = res.statusCode ?? 0;
    final bytes = _normalizeBytes(res.data);

    final contentType = (res.headers.value('content-type') ?? '').toLowerCase();
    final jsonError = _tryExtractJsonError(bytes, contentType: contentType);

    if (status < 200 || status >= 300) {
      throw Exception(jsonError ?? 'Request failed (status $status)');
    }

    if (jsonError != null) {
      throw Exception(jsonError);
    }

    return bytes;
  }

  static Future<String> saveToTemp(Uint8List bytes, String filename) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  static Future<void> shareTempFile({
    required String filePath,
    required String filename,
    required String mimeType,
    String? subject,
    String? text,
  }) async {
    await Share.shareXFiles(
      [XFile(filePath, name: filename, mimeType: mimeType)],
      subject: subject,
      text: text,
    );
  }

  static String? guessMimeTypeFromFilename(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.xlsx')) {
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    }
    if (lower.endsWith('.pdf')) return 'application/pdf';
    return null;
  }

  static Uint8List _normalizeBytes(dynamic data) {
    if (data is Uint8List) return data;
    if (data is List<int>) return Uint8List.fromList(data);
    if (data is String) return Uint8List.fromList(utf8.encode(data));
    return Uint8List(0);
  }

  static String? _tryExtractJsonError(
    Uint8List bytes, {
    required String contentType,
  }) {
    if (bytes.isEmpty) return null;

    final looksJson = contentType.contains('application/json') ||
        contentType.contains('application/problem+json') ||
        _looksLikeJsonBytes(bytes);
    if (!looksJson) return null;

    final text = utf8.decode(bytes, allowMalformed: true);
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) {
        final success = decoded['success'];
        if (success is bool && success == true) return null;
        if (decoded['error'] is String &&
            (decoded['error'] as String).isNotEmpty) {
          return decoded['error'] as String;
        }
        if (decoded['message'] is String &&
            (decoded['message'] as String).isNotEmpty) {
          return decoded['message'] as String;
        }
      }
    } catch (_) {
      // ignore
    }
    final trimmed = text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static bool _looksLikeJsonBytes(Uint8List bytes) {
    for (var i = 0; i < bytes.length && i < 16; i++) {
      final b = bytes[i];
      if (b == 0x20 || b == 0x0A || b == 0x0D || b == 0x09) continue;
      return b == 0x7B /* { */ || b == 0x5B /* [ */;
    }
    return false;
  }
}
