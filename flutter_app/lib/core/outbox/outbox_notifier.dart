import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api_client.dart';
import 'outbox_db.dart';
import 'outbox_item.dart';
import 'outbox_state.dart';
import 'outbox_store.dart';

class OutboxQueuedException implements Exception {
  OutboxQueuedException(this.message);
  final String message;
  @override
  String toString() => message;
}

class OutboxNotifier extends StateNotifier<OutboxState> {
  OutboxNotifier(this._ref)
      : _store = OutboxStore(OutboxDb()),
        super(const OutboxState()) {
    _init();
  }

  final Ref _ref;
  final OutboxStore _store;
  StreamSubscription<dynamic>? _connSub;
  bool _ready = false;

  bool get isOnline => state.isOnline;

  Future<void> _init() async {
    await _store.countPending().then((count) {
      state = state.copyWith(queuedCount: count);
    });
    final conn = Connectivity();
    final current = await conn.checkConnectivity();
    _setOnline(_isConnected(current));
    _connSub = conn.onConnectivityChanged.listen((res) {
      _setOnline(_isConnected(res));
      if (state.isOnline) {
        // ignore: unawaited_futures
        processQueue();
      }
    });
    _ready = true;
    if (state.isOnline) {
      // ignore: unawaited_futures
      processQueue();
    }
  }

  void _setOnline(bool online) {
    if (state.isOnline == online) return;
    state = state.copyWith(isOnline: online);
  }

  bool _isConnected(dynamic res) {
    if (res is ConnectivityResult) {
      return res != ConnectivityResult.none;
    }
    if (res is List<ConnectivityResult>) {
      return res.any((r) => r != ConnectivityResult.none);
    }
    return false;
  }

  Future<int> enqueue(OutboxItem item) async {
    final id = await _store.enqueue(item);
    final count = await _store.countPending();
    state = state.copyWith(queuedCount: count);
    if (state.isOnline) {
      // ignore: unawaited_futures
      processQueue();
    }
    return id;
  }

  Future<void> retryNow() async {
    await processQueue();
  }

  Future<void> processQueue() async {
    if (!_ready) return;
    if (!state.isOnline || state.isSyncing) return;
    state = state.copyWith(isSyncing: true, lastError: null);
    try {
      while (state.isOnline) {
        final next = await _store.nextPending();
        if (next == null) break;
        final ok = await _processItem(next);
        if (ok) {
          await _store.delete(next.id!);
        } else {
          // stop on network errors to avoid hammering
          if (!state.isOnline) break;
        }
      }
    } finally {
      final count = await _store.countPending();
      state = state.copyWith(
        queuedCount: count,
        isSyncing: false,
        lastSyncAt: DateTime.now(),
      );
    }
  }

  bool isNetworkError(Object e) {
    if (e is DioException) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.connectionError:
          return true;
        case DioExceptionType.unknown:
          return e.error is SocketException;
        case DioExceptionType.badResponse:
        case DioExceptionType.badCertificate:
        case DioExceptionType.cancel:
          return false;
      }
    }
    return e is SocketException;
  }

  Future<bool> _processItem(OutboxItem item) async {
    try {
      switch (item.type) {
        case 'pos_checkout':
          await _send(
            item,
            method: 'POST',
            path: '/pos/checkout',
          );
          return true;
        case 'collection':
          await _send(
            item,
            method: 'POST',
            path: '/collections',
          );
          return true;
        case 'purchase_quick':
          await _send(
            item,
            method: 'POST',
            path: '/purchases/quick',
          );
          return true;
        case 'purchase_quick_grn':
          await _processQuickGrn(item);
          return true;
        default:
          await _store.markFailed(item.id!, 'Unknown outbox type');
          return true;
      }
    } catch (e) {
      if (isNetworkError(e)) {
        state = state.copyWith(isOnline: false, lastError: e.toString());
        return false;
      }
      await _store.markFailed(item.id!, e.toString());
      state = state.copyWith(lastError: e.toString());
      return true;
    }
  }

  Future<void> _send(
    OutboxItem item, {
    required String method,
    required String path,
  }) async {
    final dio = _ref.read(dioProvider);
    final options = (item.headers ?? {}).isEmpty
        ? null
        : Options(headers: item.headers);
    if (method.toUpperCase() == 'POST') {
      await dio.post(
        path,
        data: item.body,
        queryParameters: item.queryParams,
        options: options,
      );
    } else if (method.toUpperCase() == 'PUT') {
      await dio.put(
        path,
        data: item.body,
        queryParameters: item.queryParams,
        options: options,
      );
    } else {
      await dio.request(
        path,
        data: item.body,
        queryParameters: item.queryParams,
        options: (options ?? Options()).copyWith(method: method),
      );
    }
  }

  Future<void> _processQuickGrn(OutboxItem item) async {
    final dio = _ref.read(dioProvider);
    final payload = item.meta ?? {};
    final items = (payload['items'] as List? ?? const [])
        .cast<Map<String, dynamic>>();

    // 1) Create purchase
    final purchaseRes = await dio.post(
      '/purchases/quick',
      data: payload['create_body'],
      queryParameters: item.queryParams,
      options: item.headers == null ? null : Options(headers: item.headers),
    );
    final created = (purchaseRes.data is Map && purchaseRes.data['data'] != null)
        ? purchaseRes.data['data'] as Map<String, dynamic>
        : (purchaseRes.data as Map<String, dynamic>);
    final purchaseId = created['purchase_id'] as int;

    // 2) Fetch purchase details to map to purchase_detail_id
    final purRes = await dio.get('/purchases/$purchaseId');
    final details =
        ((purRes.data['data'] as Map<String, dynamic>)['items'] as List)
            .cast<Map<String, dynamic>>();

    final receiveItems = <Map<String, dynamic>>[];
    for (final it in items) {
      final match = details.firstWhere(
        (d) => (d['product_id'] as int) == (it['product_id'] as int),
        orElse: () => const {},
      );
      final pdid = match['purchase_detail_id'] as int?;
      if (pdid == null) continue;
      receiveItems.add({
        'purchase_detail_id': pdid,
        'received_quantity': it['quantity'],
      });
    }

    await dio.post('/goods-receipts', data: {
      'purchase_id': purchaseId,
      'items': receiveItems,
    });

    final invoiceFilePath = payload['invoice_file_path'] as String?;
    if (invoiceFilePath != null && invoiceFilePath.isNotEmpty) {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(invoiceFilePath),
      });
      await dio.post('/purchases/$purchaseId/invoice', data: form);
    }
  }

  @override
  void dispose() {
    _connSub?.cancel();
    super.dispose();
  }
}

final outboxNotifierProvider =
    StateNotifierProvider<OutboxNotifier, OutboxState>((ref) {
  return OutboxNotifier(ref);
});
