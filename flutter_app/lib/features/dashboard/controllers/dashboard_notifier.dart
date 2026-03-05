import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/dashboard_repository.dart';
import '../data/models.dart';
import '../../auth/controllers/auth_notifier.dart';
import '../../../core/error_handler.dart';
import '../../../core/outbox/outbox_notifier.dart';
import 'location_notifier.dart';

class DashboardState {
  final DashboardMetrics? metrics;
  final QuickActionCounts? quickActions;
  final bool isLoading;
  final String? error;

  const DashboardState({
    this.metrics,
    this.quickActions,
    this.isLoading = false,
    this.error,
  });

  DashboardState copyWith({
    DashboardMetrics? metrics,
    QuickActionCounts? quickActions,
    bool? isLoading,
    String? error,
  }) {
    return DashboardState(
      metrics: metrics ?? this.metrics,
      quickActions: quickActions ?? this.quickActions,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class DashboardNotifier extends StateNotifier<DashboardState> {
  DashboardNotifier(this._repository, this._ref)
      : super(const DashboardState()) {
    _timer = Timer.periodic(const Duration(seconds: 45), (_) {
      // ignore: unawaited_futures
      _silentRefresh();
    });
  }

  final DashboardRepository _repository;
  final Ref _ref;
  Timer? _timer;
  bool _refreshing = false;

  Future<void> load({bool showLoading = true}) async {
    if (state.isLoading) return;
    if (showLoading) {
      state = state.copyWith(isLoading: true, error: null);
    } else {
      state = state.copyWith(error: null);
    }
    try {
      // Use selected location if available; some endpoints require it.
      final locState = _ref.read(locationNotifierProvider);
      final selectedLocationId = locState.selected?.locationId;

      final metrics =
          await _repository.getMetrics(locationId: selectedLocationId);
      final actions =
          await _repository.getQuickActions(locationId: selectedLocationId);
      state = state.copyWith(
        isLoading: false,
        metrics: metrics,
        quickActions: actions,
      );
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401) {
        try {
          await _ref.read(authRepositoryProvider).logout();
        } catch (_) {}
        _ref.read(authNotifierProvider.notifier).state = const AuthState();
        return;
      }
      // Avoid wiping the dashboard when background refresh fails.
      if (showLoading || state.metrics == null) {
        state = state.copyWith(
          isLoading: false,
          error: ErrorHandler.message(e),
        );
      } else {
        state = state.copyWith(isLoading: false, error: null);
      }
    }
  }

  Future<void> _silentRefresh() async {
    if (_refreshing) return;
    final outbox = _ref.read(outboxNotifierProvider);
    if (!outbox.isOnline) return;
    _refreshing = true;
    try {
      await load(showLoading: false);
    } finally {
      _refreshing = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final dashboardNotifierProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  final repo = ref.watch(dashboardRepositoryProvider);
  final notifier = DashboardNotifier(repo, ref);
  notifier.load();
  return notifier;
});
