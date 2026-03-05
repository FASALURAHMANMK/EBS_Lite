import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api_client.dart';
import '../error_handler.dart';
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

  static const int _onlineProbeIntervalSeconds = 15;

  final Ref _ref;
  final OutboxStore _store;
  StreamSubscription<dynamic>? _connSub;
  Timer? _probeTimer;
  bool _probing = false;
  bool _everProbed = false;
  int _probeIntervalSeconds = 3;
  int _probeCountdownSeconds = 0;
  bool _ready = false;
  bool _hasConnectivity = true;

  bool get isOnline => state.isOnline;

  Future<void> _init() async {
    await _store.countPending().then((count) {
      state = state.copyWith(queuedCount: count);
    });
    final conn = Connectivity();
    final current = await conn.checkConnectivity();
    _connSub = conn.onConnectivityChanged.listen((res) {
      _onConnectivity(res);
    });
    _ready = true;
    _onConnectivity(current);
  }

  void _setOnline(bool online) {
    if (state.isOnline == online) return;
    state = state.copyWith(isOnline: online);
    if (online) {
      // ignore: unawaited_futures
      processQueue();
    }
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

  void _onConnectivity(dynamic res) {
    _hasConnectivity = _isConnected(res);
    if (!_hasConnectivity) {
      _stopProbe();
      state = state.copyWith(
        hasConnectivity: false,
        isChecking: false,
      );
      _setOnline(false);
      return;
    }
    state = state.copyWith(hasConnectivity: true);
    // Connectivity exists; probe server reachability and, if online, resume sync.
    _startProbeIfNeeded();
    // Probe immediately on connectivity changes to detect "Wi‑Fi w/o internet".
    // ignore: unawaited_futures
    _probeServerOnce(setChecking: !_everProbed);
  }

  void _startProbeIfNeeded() {
    if (!_ready) return;
    if (!_hasConnectivity) return;
    if (_probeTimer != null) return;
    _probeIntervalSeconds =
        state.isOnline ? _onlineProbeIntervalSeconds : _probeIntervalSeconds;
    _probeCountdownSeconds = 0;
    _probeTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (_probeCountdownSeconds > 0) {
        _probeCountdownSeconds--;
        return;
      }
      await _probeServerOnce();
      if (state.isOnline) {
        _probeIntervalSeconds = _onlineProbeIntervalSeconds;
      } else {
        // Increase backoff up to 30s if still offline
        _probeIntervalSeconds = (_probeIntervalSeconds + 3).clamp(3, 30);
      }
      _probeCountdownSeconds = _probeIntervalSeconds;
    });
  }

  void _stopProbe() {
    _probeTimer?.cancel();
    _probeTimer = null;
  }

  String _healthUrlFromBaseUrl(String baseUrl) {
    Uri uri;
    try {
      uri = Uri.parse(baseUrl);
    } catch (_) {
      return '$baseUrl/health';
    }
    var path = uri.path.replaceAll(RegExp(r'/+$'), '');
    if (path.endsWith('/api/v1')) {
      path = path.substring(0, path.length - '/api/v1'.length);
    }
    final root =
        uri.replace(path: path, query: null, fragment: null).toString();
    return root.endsWith('/') ? '${root}health' : '$root/health';
  }

  Future<void> _probeServerOnce({bool setChecking = false}) async {
    if (!_hasConnectivity) {
      _setOnline(false);
      return;
    }
    if (_probing) return;
    _probing = true;
    if (setChecking) {
      state = state.copyWith(isChecking: true);
    }
    final base = _ref.read(dioProvider).options.baseUrl;
    final healthUrl = _healthUrlFromBaseUrl(base);
    final dio = Dio(
      BaseOptions(
        baseUrl: '',
        connectTimeout: const Duration(seconds: 2),
        sendTimeout: const Duration(seconds: 2),
        receiveTimeout: const Duration(seconds: 2),
      ),
    );
    try {
      await dio.get(healthUrl);
      if (!state.isOnline) _setOnline(true);
    } on DioException catch (e) {
      // If we received a response, the server is reachable even if /health is not 200.
      if (e.type == DioExceptionType.badResponse &&
          e.response?.statusCode != null) {
        if (!state.isOnline) _setOnline(true);
        return;
      }
      // stay offline on actual connectivity errors
      if (isNetworkError(e)) {
        _setOnline(false);
      }
    } catch (_) {
      // keep offline
    } finally {
      _probing = false;
      _everProbed = true;
      if (setChecking && state.isChecking) {
        state = state.copyWith(isChecking: false);
      } else if (!setChecking && state.isChecking) {
        // Safety: avoid getting stuck in "checking" if a probe ran from a timer.
        state = state.copyWith(isChecking: false);
      }
    }
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

  Future<void> recheckOnline() async {
    final conn = Connectivity();
    final current = await conn.checkConnectivity();
    _hasConnectivity = _isConnected(current);
    if (!_hasConnectivity) {
      _stopProbe();
      state = state.copyWith(
        hasConnectivity: false,
        isChecking: false,
      );
      _setOnline(false);
      return;
    }

    state = state.copyWith(hasConnectivity: true);
    _probeIntervalSeconds = 3;
    _probeCountdownSeconds = 0;
    _startProbeIfNeeded();
    await _probeServerOnce(setChecking: true);
  }

  Future<List<OutboxItem>> listFailed({int limit = 50}) {
    return _store.listFailed(limit: limit);
  }

  Future<List<OutboxItem>> listPending({int limit = 200}) {
    return _store.listPending(limit: limit);
  }

  Future<void> retryItem(int id) async {
    await _store.markQueued(id);
    if (state.isOnline) {
      await processQueue();
    }
  }

  Future<void> discardItem(int id) async {
    await _store.delete(id);
    final count = await _store.countPending();
    state = state.copyWith(queuedCount: count);
  }

  Map<String, dynamic> _buildHeaders(OutboxItem item) {
    final headers = <String, dynamic>{...?item.headers};
    final idemKey = (item.idempotencyKey ?? '').trim();
    if (idemKey.isNotEmpty) {
      headers.putIfAbsent('Idempotency-Key', () => idemKey);
      headers.putIfAbsent('X-Idempotency-Key', () => idemKey);
    }
    return headers;
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
        case 'expense':
          await _send(
            item,
            method: 'POST',
            path: '/expenses',
          );
          return true;
        default:
          await _store.markFailed(item.id!, 'Unknown outbox type');
          return true;
      }
    } catch (e) {
      if (isNetworkError(e)) {
        state = state.copyWith(
          isOnline: false,
          lastError: ErrorHandler.message(e),
        );
        _probeIntervalSeconds = 3;
        _probeCountdownSeconds = 0;
        _startProbeIfNeeded();
        return false;
      }
      final msg = ErrorHandler.message(e);
      await _store.markFailed(item.id!, msg);
      state = state.copyWith(lastError: msg);
      return true;
    }
  }

  Future<void> _send(
    OutboxItem item, {
    required String method,
    required String path,
  }) async {
    final dio = _ref.read(dioProvider);
    final headers = _buildHeaders(item);
    final options = headers.isEmpty ? null : Options(headers: headers);
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
    final headers = _buildHeaders(item);
    final options = headers.isEmpty ? null : Options(headers: headers);
    final payload = item.meta ?? {};
    final items =
        (payload['items'] as List? ?? const []).cast<Map<String, dynamic>>();

    // 1) Create purchase
    final purchaseRes = await dio.post(
      '/purchases/quick',
      data: payload['create_body'],
      queryParameters: item.queryParams,
      options: options,
    );
    final created =
        (purchaseRes.data is Map && purchaseRes.data['data'] != null)
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
    _stopProbe();
    super.dispose();
  }
}

final outboxNotifierProvider =
    StateNotifierProvider<OutboxNotifier, OutboxState>((ref) {
  return OutboxNotifier(ref);
});
