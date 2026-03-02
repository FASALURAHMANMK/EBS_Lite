import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/controllers/auth_notifier.dart';
import '../../dashboard/controllers/location_notifier.dart';
import '../data/accounts_repository.dart';

class TrainingModeState {
  const TrainingModeState({
    this.enabled = false,
    this.registerId,
    this.loading = false,
    this.error,
  });

  final bool enabled;
  final int? registerId;
  final bool loading;
  final String? error;

  TrainingModeState copyWith({
    bool? enabled,
    int? registerId,
    bool? loading,
    String? error,
  }) {
    return TrainingModeState(
      enabled: enabled ?? this.enabled,
      registerId: registerId ?? this.registerId,
      loading: loading ?? this.loading,
      error: error,
    );
  }
}

class TrainingModeNotifier extends StateNotifier<TrainingModeState> {
  TrainingModeNotifier(this._ref) : super(const TrainingModeState()) {
    _authSub = _ref.listen(authNotifierProvider, (prev, next) {
      final hadSession = (prev?.user != null && prev?.company != null);
      final hasSession = (next.user != null && next.company != null);
      if (hadSession != hasSession) {
        unawaited(refresh());
      }
    });
    _locationSub = _ref.listen(locationNotifierProvider, (prev, next) {
      final prevId = prev?.selected?.locationId;
      final nextId = next.selected?.locationId;
      if (prevId != nextId) {
        unawaited(refresh());
      }
    });
    unawaited(refresh());
  }

  final Ref _ref;
  late final ProviderSubscription _authSub;
  late final ProviderSubscription _locationSub;

  @override
  void dispose() {
    _authSub.close();
    _locationSub.close();
    super.dispose();
  }

  Future<void> refresh() async {
    final auth = _ref.read(authNotifierProvider);
    final loc = _ref.read(locationNotifierProvider).selected;
    if (auth.user == null || auth.company == null || loc == null) {
      state = const TrainingModeState(enabled: false, registerId: null);
      return;
    }

    state = state.copyWith(loading: true, error: null);
    try {
      final repo = _ref.read(accountsRepositoryProvider);
      final registers = await repo.getCashRegisters(locationId: loc.locationId);
      final open = registers.where((r) => r.status.toUpperCase() == 'OPEN');
      if (open.isEmpty) {
        state = const TrainingModeState(enabled: false, registerId: null);
        return;
      }
      final reg = open.first;
      state = TrainingModeState(
        enabled: reg.trainingMode,
        registerId: reg.registerId,
        loading: false,
      );
    } catch (e) {
      state = TrainingModeState(
        enabled: false,
        registerId: null,
        loading: false,
        error: e.toString(),
      );
    }
  }
}

final trainingModeNotifierProvider =
    StateNotifierProvider<TrainingModeNotifier, TrainingModeState>((ref) {
  return TrainingModeNotifier(ref);
});

final trainingModeEnabledProvider = Provider<bool>((ref) {
  final auth = ref.watch(authNotifierProvider);
  if (auth.user == null || auth.company == null) return false;
  return ref.watch(trainingModeNotifierProvider).enabled;
});
