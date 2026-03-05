import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api_client.dart';
import '../error_handler.dart';
import '../outbox/outbox_notifier.dart';
import '../../features/auth/controllers/auth_notifier.dart';
import '../../features/dashboard/controllers/location_notifier.dart';

class OfflineNumberUnavailable implements Exception {
  OfflineNumberUnavailable(this.message);
  final String message;
  @override
  String toString() => message;
}

class OfflineNumberingService {
  OfflineNumberingService(this._dio, this._prefs, this._ref);
  final Dio _dio;
  final SharedPreferences _prefs;
  final Ref _ref;

  static const int _defaultBlockSize = 100;
  static const int _lowWatermark = 20;

  String _key({
    required int companyId,
    required int locationId,
    required String sequenceName,
  }) =>
      'offline_number_block:$companyId:$locationId:$sequenceName';

  Map<String, dynamic>? _readBlock(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeBlock(String key, Map<String, dynamic> block) async {
    await _prefs.setString(key, jsonEncode(block));
  }

  Future<Map<String, dynamic>> _reserve({
    required int companyId,
    required int locationId,
    required String sequenceName,
    int blockSize = _defaultBlockSize,
  }) async {
    final outbox = _ref.read(outboxNotifierProvider.notifier);
    if (!outbox.isOnline) {
      throw OfflineNumberUnavailable(
          'Connect once to reserve receipt numbers for offline use.');
    }

    final res = await _dio.post(
      '/pos/numbering/reserve',
      queryParameters: {'location_id': locationId},
      data: {
        'sequence_name': sequenceName,
        'block_size': blockSize,
      },
    );
    final body = res.data;
    final data = (body is Map && body['data'] is Map)
        ? (body['data'] as Map).cast<String, dynamic>()
        : (body as Map).cast<String, dynamic>();

    final prefix = (data['prefix'] as String?) ?? '';
    final len = (data['sequence_length'] as num?)?.toInt() ?? 6;
    final start = (data['start_number'] as num?)?.toInt() ?? 0;
    final end = (data['end_number'] as num?)?.toInt() ?? 0;
    if (start <= 0 || end <= 0 || end < start) {
      throw OfflineNumberUnavailable('Invalid numbering reservation response.');
    }

    return {
      'sequence_name': sequenceName,
      'prefix': prefix,
      'sequence_length': len,
      'next_number': start,
      'end_number': end,
      'reserved_at_ms': DateTime.now().toUtc().millisecondsSinceEpoch,
    };
  }

  String _formatNumber(Map<String, dynamic> block, int n) {
    final prefix = (block['prefix'] as String?) ?? '';
    final len = (block['sequence_length'] as num?)?.toInt() ?? 6;
    final padded = n.toString().padLeft(len, '0');
    return '$prefix$padded';
  }

  String? peekNextSaleNumber({required bool training}) {
    final auth = _ref.read(authNotifierProvider);
    final loc = _ref.read(locationNotifierProvider).selected;
    final companyId = auth.company?.companyId;
    final locationId = loc?.locationId;
    if (companyId == null || companyId <= 0 || locationId == null) return null;

    final sequenceName = training ? 'sale_training' : 'sale';
    final key = _key(
      companyId: companyId,
      locationId: locationId,
      sequenceName: sequenceName,
    );

    final block = _readBlock(key);
    if (block == null) return null;
    final next = (block['next_number'] as num?)?.toInt() ?? 0;
    final end = (block['end_number'] as num?)?.toInt() ?? 0;
    if (next <= 0 || end <= 0 || next > end) return null;
    return _formatNumber(block, next);
  }

  Future<String> nextSaleNumber({required bool training}) async {
    final auth = _ref.read(authNotifierProvider);
    final loc = _ref.read(locationNotifierProvider).selected;
    final companyId = auth.company?.companyId;
    final locationId = loc?.locationId;
    if (companyId == null || companyId <= 0 || locationId == null) {
      throw OfflineNumberUnavailable('Select a location first.');
    }

    final sequenceName = training ? 'sale_training' : 'sale';
    final key = _key(
      companyId: companyId,
      locationId: locationId,
      sequenceName: sequenceName,
    );

    var block = _readBlock(key);
    var next = (block?['next_number'] as num?)?.toInt() ?? 0;
    final end = (block?['end_number'] as num?)?.toInt() ?? 0;

    if (block == null || next <= 0 || end <= 0 || next > end) {
      try {
        block = await _reserve(
          companyId: companyId,
          locationId: locationId,
          sequenceName: sequenceName,
        );
        next = (block['next_number'] as num).toInt();
      } on DioException catch (e) {
        if (ErrorHandler.isNetworkError(e)) {
          throw OfflineNumberUnavailable(
              'No reserved receipt numbers available. Connect to internet and try again.');
        }
        rethrow;
      }
    }

    final formatted = _formatNumber(block, next);
    block['next_number'] = next + 1;
    await _writeBlock(key, block);

    // If we're online and running low, top up in the background.
    final remaining = end - next;
    final outbox = _ref.read(outboxNotifierProvider.notifier);
    if (outbox.isOnline && remaining <= _lowWatermark) {
      // ignore: unawaited_futures
      prefetchSaleNumbersIfNeeded(training: training);
    }

    return formatted;
  }

  Future<void> prefetchSaleNumbersIfNeeded({required bool training}) async {
    final auth = _ref.read(authNotifierProvider);
    final loc = _ref.read(locationNotifierProvider).selected;
    final companyId = auth.company?.companyId;
    final locationId = loc?.locationId;
    if (companyId == null || companyId <= 0 || locationId == null) return;

    final sequenceName = training ? 'sale_training' : 'sale';
    final key = _key(
      companyId: companyId,
      locationId: locationId,
      sequenceName: sequenceName,
    );
    final block = _readBlock(key);
    final next = (block?['next_number'] as num?)?.toInt() ?? 0;
    final end = (block?['end_number'] as num?)?.toInt() ?? 0;
    final remaining = (end > 0 && next > 0) ? (end - next + 1) : 0;

    final outbox = _ref.read(outboxNotifierProvider.notifier);
    if (!outbox.isOnline) return;
    if (remaining > _lowWatermark) return;

    try {
      final fresh = await _reserve(
        companyId: companyId,
        locationId: locationId,
        sequenceName: sequenceName,
        blockSize: _defaultBlockSize,
      );
      await _writeBlock(key, fresh);
    } on DioException catch (e) {
      if (ErrorHandler.isNetworkError(e)) return;
      rethrow;
    }
  }
}

final offlineNumberingServiceProvider =
    Provider<OfflineNumberingService>((ref) {
  final dio = ref.watch(dioProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return OfflineNumberingService(dio, prefs, ref);
});
