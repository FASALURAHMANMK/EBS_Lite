import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api_client.dart';
import '../../../core/outbox/outbox_notifier.dart';
import '../data/dashboard_customization.dart';
import '../data/user_preferences_repository.dart';

class DashboardCustomizationNotifier
    extends StateNotifier<DashboardCustomization> {
  DashboardCustomizationNotifier(this._ref, this._prefs)
      : super(DashboardCustomization.defaults) {
    _loadLocal();
    // ignore: unawaited_futures
    refreshFromServer();
  }

  final Ref _ref;
  final SharedPreferences _prefs;

  static const _cacheKey = 'dashboard_customization_cache';
  static const _needsSyncKey = 'dashboard_customization_needs_sync';

  void _loadLocal() {
    final raw = _prefs.getString(_cacheKey);
    if (raw == null || raw.trim().isEmpty) return;
    final parsed = DashboardCustomization.tryParse(raw);
    if (parsed == null) return;
    state = _sanitize(parsed);
  }

  DashboardCustomization _sanitize(DashboardCustomization next) {
    final seen = <String>{};
    final shortcuts = <String>[];
    for (final id in next.shortcutActionIds) {
      final normalized = id.trim();
      if (normalized.isEmpty) continue;
      if (seen.add(normalized)) shortcuts.add(normalized);
    }
    final quick = next.quickActionId?.trim();
    return DashboardCustomization(
      shortcutActionIds: shortcuts,
      quickActionId: (quick == null || quick.isEmpty) ? null : quick,
    );
  }

  Future<void> _saveLocalAndMarkDirty() async {
    await _prefs.setString(_cacheKey, state.encode());
    await _prefs.setBool(_needsSyncKey, true);
  }

  bool get _isOnline => _ref.read(outboxNotifierProvider).isOnline;

  Future<void> refreshFromServer() async {
    if (!_isOnline) return;
    try {
      final repo = _ref.read(userPreferencesRepositoryProvider);
      final prefs = await repo.getPreferences();
      final raw = prefs[DashboardCustomization.preferenceKey];
      if (raw == null || raw.trim().isEmpty) return;
      final parsed = DashboardCustomization.tryParse(raw);
      if (parsed == null) return;
      state = _sanitize(parsed);
      await _prefs.setString(_cacheKey, state.encode());
      await _prefs.setBool(_needsSyncKey, false);
    } catch (_) {
      // Keep local state on failures; offline-first UX.
    }
  }

  Future<void> syncIfNeeded() async {
    if (!_isOnline) return;
    final dirty = _prefs.getBool(_needsSyncKey) ?? false;
    if (!dirty) return;
    await _syncNow();
  }

  Future<void> _syncNow() async {
    try {
      final repo = _ref.read(userPreferencesRepositoryProvider);
      await repo.upsertPreference(
        key: DashboardCustomization.preferenceKey,
        value: state.encode(),
      );
      await _prefs.setBool(_needsSyncKey, false);
    } catch (_) {
      // Keep dirty flag for a later retry.
    }
  }

  Future<void> setShortcuts(List<String> shortcutIds) async {
    state = _sanitize(
      state.copyWith(shortcutActionIds: shortcutIds),
    );
    await _saveLocalAndMarkDirty();
    if (_isOnline) {
      await _syncNow();
    }
  }

  Future<void> setQuickAction(String? actionId) async {
    state = _sanitize(
      state.copyWith(quickActionId: actionId),
    );
    await _saveLocalAndMarkDirty();
    if (_isOnline) {
      await _syncNow();
    }
  }

  Future<void> resetToDefaults() async {
    state = DashboardCustomization.defaults;
    await _saveLocalAndMarkDirty();
    if (_isOnline) {
      await _syncNow();
    }
  }
}

final dashboardCustomizationProvider = StateNotifierProvider<
    DashboardCustomizationNotifier, DashboardCustomization>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final notifier = DashboardCustomizationNotifier(ref, prefs);

  ref.listen<bool>(
    outboxNotifierProvider.select((s) => s.isOnline),
    (prev, next) {
      if (next && (prev != true)) {
        // ignore: unawaited_futures
        notifier.syncIfNeeded();
        // ignore: unawaited_futures
        notifier.refreshFromServer();
      }
    },
  );

  return notifier;
});
