import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../data/dashboard_repository.dart';
import '../data/models.dart';
import '../../auth/controllers/auth_notifier.dart';
import '../../../core/error_handler.dart';
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
      : super(const DashboardState());

  final DashboardRepository _repository;
  final Ref _ref;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
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
      state = state.copyWith(
        isLoading: false,
        error: ErrorHandler.message(e),
      );
    }
  }
}

final dashboardNotifierProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  final repo = ref.watch(dashboardRepositoryProvider);
  final notifier = DashboardNotifier(repo, ref);
  notifier.load();
  return notifier;
});
