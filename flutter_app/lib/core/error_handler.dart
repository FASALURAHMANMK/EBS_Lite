import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../features/auth/data/models.dart';
import 'offline_cache/offline_exception.dart';

class ErrorHandler {
  static bool isNetworkError(Object error) {
    if (error is OfflineException) return true;
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.connectionError:
          return true;
        case DioExceptionType.unknown:
          return error.error is SocketException;
        case DioExceptionType.badResponse:
        case DioExceptionType.badCertificate:
        case DioExceptionType.cancel:
          return false;
      }
    }
    return error is SocketException;
  }

  static String message(Object error) {
    if (error is AuthException) {
      return error.message;
    }
    if (error is OfflineException) {
      final msg = error.message.trim();
      return msg.isNotEmpty ? msg : 'You appear to be offline.';
    }
    if (error is StateError) {
      final msg = error.message.trim();
      return msg.isNotEmpty ? msg : 'Invalid state. Please try again.';
    }
    if (error is FormatException) {
      final msg = error.message.trim();
      return msg.isNotEmpty ? msg : 'Invalid format.';
    }
    if (error is DioException) {
      // Prefer explicit message from backend if present
      final backendMsg = _extractMessage(error);
      if (backendMsg != null && backendMsg.trim().isNotEmpty) {
        return backendMsg;
      }

      final type = error.type;
      switch (type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'Connection timed out. Please try again.';
        case DioExceptionType.badCertificate:
          return 'Certificate error. Please try again later.';
        case DioExceptionType.cancel:
          return 'Request was cancelled.';
        case DioExceptionType.connectionError:
          return 'Network error. Check your internet connection.';
        case DioExceptionType.unknown:
        case DioExceptionType.badResponse:
          final code = error.response?.statusCode;
          if (code != null) {
            if (code == 401) {
              return 'Your session has expired. Please sign in again.';
            }
            if (code == 403) {
              return 'You do not have permission to perform this action.';
            }
            if (code == 404) {
              return 'Requested resource was not found.';
            }
            if (code == 409) {
              return 'A conflict occurred. Please refresh and try again.';
            }
            if (code == 422) {
              return 'Some inputs are invalid. Please review and try again.';
            }
            if (code == 429) {
              return 'Too many requests. Please wait a moment and retry.';
            }
            if (code >= 500) {
              return 'Server error. Please try again later.';
            }
            return 'Request failed (status $code). Please try again.';
          }
          return 'Something went wrong. Please try again.';
      }
    }

    // Preserve intentional, user-facing messages from thrown Exceptions.
    final raw = error.toString();
    if (raw.startsWith('Exception: ')) {
      final msg = raw.substring('Exception: '.length).trim();
      if (msg.isNotEmpty) return msg;
    }
    if (raw.startsWith('StateError: ')) {
      final msg = raw.substring('StateError: '.length).trim();
      if (msg.isNotEmpty) return msg;
    }
    return 'Something went wrong. Please try again.';
  }

  static String? _extractMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      // Prefer 'error' for more specific DB/validation messages; fallback to 'message'
      if (data['error'] is String && (data['error'] as String).isNotEmpty) {
        return data['error'] as String;
      }
      if (data['message'] is String && (data['message'] as String).isNotEmpty) {
        return data['message'] as String;
      }
      // Backend validation returns a map in `data` with field->message
      final validation = data['data'];
      if (validation is Map) {
        try {
          final parts = <String>[];
          validation.forEach((k, v) {
            parts.add(v.toString());
          });
          if (parts.isNotEmpty) return parts.join('\n');
        } catch (_) {}
      }
    }
    // Some endpoints (exports) use ResponseType.bytes; DioException.data may be bytes.
    if (data is Uint8List || data is List<int> || data is String) {
      try {
        final bytes = data is Uint8List
            ? data
            : (data is List<int>)
                ? Uint8List.fromList(data)
                : Uint8List.fromList(utf8.encode(data));
        final text = utf8.decode(bytes, allowMalformed: true).trim();
        if (text.isEmpty) return null;
        final decoded = jsonDecode(text);
        if (decoded is Map<String, dynamic>) {
          if (decoded['error'] is String &&
              (decoded['error'] as String).isNotEmpty) {
            return decoded['error'] as String;
          }
          if (decoded['message'] is String &&
              (decoded['message'] as String).isNotEmpty) {
            return decoded['message'] as String;
          }
        }
        // Fallback: return raw response if it's short-ish and looks like an error.
        return text.length > 400 ? null : text;
      } catch (_) {
        // ignore
      }
    }
    return null;
  }
}
