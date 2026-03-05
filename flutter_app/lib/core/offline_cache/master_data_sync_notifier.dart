import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api_client.dart';
import '../error_handler.dart';
import '../outbox/outbox_notifier.dart';
import '../../features/auth/controllers/auth_notifier.dart';
import '../../features/dashboard/controllers/location_notifier.dart';
import 'cache_store.dart';
import 'offline_cache_providers.dart';
import 'offline_numbering.dart';

class MasterDataSyncState {
  const MasterDataSyncState({
    this.isSyncing = false,
    this.lastSyncAt,
    this.lastError,
  });

  final bool isSyncing;
  final DateTime? lastSyncAt;
  final String? lastError;

  MasterDataSyncState copyWith({
    bool? isSyncing,
    DateTime? lastSyncAt,
    String? lastError,
  }) {
    return MasterDataSyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastError: lastError,
    );
  }
}

class MasterDataSyncNotifier extends StateNotifier<MasterDataSyncState> {
  MasterDataSyncNotifier(this._dio, this._store, this._ref)
      : super(const MasterDataSyncState()) {
    _timer = Timer.periodic(const Duration(minutes: 5), (_) {
      // ignore: unawaited_futures
      syncNow();
    });
  }

  final Dio _dio;
  final CacheStore _store;
  final Ref _ref;
  Timer? _timer;

  static const Duration _minInterval = Duration(minutes: 10);

  List<dynamic> _asList(Response res) {
    final body = res.data;
    if (body is List) return body;
    if (body is Map<String, dynamic>) {
      final data = body['data'];
      if (data is List) return data;
    }
    return const [];
  }

  Future<void> syncNow({bool force = false}) async {
    if (state.isSyncing) return;

    final outbox = _ref.read(outboxNotifierProvider);
    if (!outbox.isOnline) return;

    final auth = _ref.read(authNotifierProvider);
    final loc = _ref.read(locationNotifierProvider).selected;
    final companyId = auth.company?.companyId;
    final locationId = loc?.locationId;
    if (companyId == null || companyId <= 0 || locationId == null) return;

    if (!force && state.lastSyncAt != null) {
      final age = DateTime.now().difference(state.lastSyncAt!);
      if (age < _minInterval) return;
    }

    state = state.copyWith(isSyncing: true, lastError: null);
    try {
      // Pull master data in a predictable order (products first for POS).
      final productsRes = await _dio.get(
        '/pos/products',
        queryParameters: {'location_id': locationId},
      );
      await _store.upsertProducts(
        locationId: locationId,
        items: _asList(productsRes).cast<Map<String, dynamic>>(),
      );

      final customersRes = await _dio.get('/pos/customers');
      await _store.upsertCustomers(
        _asList(customersRes).cast<Map<String, dynamic>>(),
      );

      final pmRes = await _dio.get('/pos/payment-methods');
      await _store.upsertPaymentMethods(
        _asList(pmRes).cast<Map<String, dynamic>>(),
      );

      // Currencies (required for POS multi-currency payments).
      try {
        final curRes = await _dio.get('/currencies');
        await _store.upsertCurrencies(
          _asList(curRes).cast<Map<String, dynamic>>(),
        );
      } on DioException catch (e) {
        // Ignore unsupported/permission failures; still allow base-currency-only offline mode.
        final code = e.response?.statusCode;
        if (code != null && (code == 403 || code == 404)) {
          // ignore
        } else if (ErrorHandler.isNetworkError(e)) {
          // ignore
        } else {
          // ignore
        }
      } catch (_) {
        // ignore
      }

      // Payment method currency mappings (best-effort).
      try {
        Response res;
        try {
          res = await _dio.get('/pos/payment-methods/currencies');
        } on DioException catch (e) {
          if (e.response?.statusCode == 404) {
            res = await _dio.get('/settings/payment-methods/currencies');
          } else {
            rethrow;
          }
        }
        await _store.upsertPaymentMethodCurrencies(
          _asList(res).cast<Map<String, dynamic>>(),
        );
      } on DioException catch (e) {
        final code = e.response?.statusCode;
        if (code != null && (code == 403 || code == 404)) {
          // ignore
        } else if (ErrorHandler.isNetworkError(e)) {
          // ignore
        } else {
          // ignore
        }
      } catch (_) {
        // ignore
      }

      final suppliersRes = await _dio.get('/suppliers');
      await _store.upsertSuppliers(
        _asList(suppliersRes).cast<Map<String, dynamic>>(),
      );

      final catsRes = await _dio.get('/expenses/categories');
      await _store.upsertExpenseCategories(
        _asList(catsRes).cast<Map<String, dynamic>>(),
      );

      // Recent transaction history for offline lookup (best-effort).
      try {
        final nowDt = DateTime.now();
        final from = nowDt.subtract(const Duration(days: 7));
        String d(DateTime v) =>
            '${v.year.toString().padLeft(4, '0')}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')}';
        final histRes = await _dio.get(
          '/sales/history',
          queryParameters: {
            'date_from': d(from),
            'date_to': d(nowDt),
            'location_id': locationId,
          },
        );
        await _store.upsertSalesHistory(
          locationId: locationId,
          items: _asList(histRes).cast<Map<String, dynamic>>(),
        );
      } on DioException catch (e) {
        // Ignore permission/unsupported endpoint failures.
        final code = e.response?.statusCode;
        if (code != null && (code == 403 || code == 404)) {
          // ignore
        } else if (ErrorHandler.isNetworkError(e)) {
          // ignore
        } else {
          // ignore other history errors for now
        }
      } catch (_) {
        // ignore
      }

      // Keep sale numbering blocks ready for offline checkouts.
      // ignore: unawaited_futures
      _ref
          .read(offlineNumberingServiceProvider)
          .prefetchSaleNumbersIfNeeded(training: false);

      final now = DateTime.now();
      await _store.setMeta(
        'master_sync:last_ok_ms:$companyId:$locationId',
        now.toUtc().millisecondsSinceEpoch.toString(),
      );
      state =
          state.copyWith(isSyncing: false, lastSyncAt: now, lastError: null);
    } on DioException catch (e) {
      if (ErrorHandler.isNetworkError(e)) {
        // Stay silent; UI can show offline banner elsewhere.
        state = state.copyWith(isSyncing: false, lastError: null);
        return;
      }
      state =
          state.copyWith(isSyncing: false, lastError: ErrorHandler.message(e));
    } catch (e) {
      state =
          state.copyWith(isSyncing: false, lastError: ErrorHandler.message(e));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final masterDataSyncNotifierProvider =
    StateNotifierProvider<MasterDataSyncNotifier, MasterDataSyncState>((ref) {
  final dio = ref.watch(dioProvider);
  final store = ref.watch(cacheStoreProvider);
  return MasterDataSyncNotifier(dio, store, ref);
});
