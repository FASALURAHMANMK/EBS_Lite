import 'package:dio/dio.dart';

import '../features/auth/data/models.dart';

class ErrorHandler {
  static String message(Object error) {
    if (error is AuthException) {
      return error.message;
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
    return 'Something went wrong. Please try again.';
  }

  static String? _extractMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      if (data['message'] is String) return data['message'] as String;
      if (data['error'] is String) return data['error'] as String;
      final errors = data['errors'];
      if (errors is List) {
        return errors.join(', ');
      }
    }
    return null;
  }
}

