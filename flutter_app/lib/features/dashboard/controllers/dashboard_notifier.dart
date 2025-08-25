import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/dashboard_repository.dart';
import '../data/models.dart';

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
  DashboardNotifier(this._repository) : super(const DashboardState());

  final DashboardRepository _repository;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final metrics = await _repository.getMetrics();
      final actions = await _repository.getQuickActions();
      state = state.copyWith(
        isLoading: false,
        metrics: metrics,
        quickActions: actions,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final dashboardNotifierProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  final repo = ref.watch(dashboardRepositoryProvider);
  final notifier = DashboardNotifier(repo);
  notifier.load();
  return notifier;
});
