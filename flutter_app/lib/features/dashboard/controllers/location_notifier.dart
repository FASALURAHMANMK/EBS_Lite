import 'package:ebs_lite/features/auth/data/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../data/location_repository.dart';
import '../data/models.dart';
import '../../../core/api_client.dart';
import '../../auth/controllers/auth_notifier.dart';
import '../../../core/error_handler.dart';

class LocationState {
  final List<Location> locations;
  final Location? selected;
  final bool isLoading;
  final String? error;

  const LocationState({
    this.locations = const [],
    this.selected,
    this.isLoading = false,
    this.error,
  });

  LocationState copyWith({
    List<Location>? locations,
    Location? selected,
    bool? isLoading,
    String? error,
  }) {
    return LocationState(
      locations: locations ?? this.locations,
      selected: selected ?? this.selected,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class LocationNotifier extends StateNotifier<LocationState> {
  LocationNotifier(this._repository, this._prefs, this._ref)
      : super(const LocationState());

  static const selectedLocationKey = AuthRepository.selectedLocationKey;
  static const _cachedLocationsKey = AuthRepository.cachedLocationsKey;

  final LocationRepository _repository;
  final SharedPreferences _prefs;
  final Ref _ref;

  Future<void> load(int companyId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final list = await _repository.fetchLocations(companyId);
      await _prefs.setString(
        _cachedLocationsKey,
        jsonEncode({
          'company_id': companyId,
          'locations': list
              .map((l) => {'location_id': l.locationId, 'name': l.name})
              .toList(),
        }),
      );
      Location? selected;
      final stored = _prefs.getInt(selectedLocationKey);
      if (stored != null) {
        try {
          selected = list.firstWhere((l) => l.locationId == stored);
        } catch (_) {
          selected = null;
        }
      }
      state = state.copyWith(
        isLoading: false,
        locations: list,
        selected: selected ?? (list.isNotEmpty ? list.first : null),
      );
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401) {
        try {
          await _ref.read(authRepositoryProvider).logout();
        } catch (_) {}
        _ref.read(authNotifierProvider.notifier).state = const AuthState();
        return;
      }
      if (ErrorHandler.isNetworkError(e)) {
        final cached = _prefs.getString(_cachedLocationsKey);
        if (cached != null && cached.trim().isNotEmpty) {
          try {
            final decoded = jsonDecode(cached);
            if (decoded is Map &&
                decoded['company_id'] == companyId &&
                decoded['locations'] is List) {
              final raw = (decoded['locations'] as List).cast<dynamic>();
              final list = raw
                  .whereType<Map>()
                  .map((m) => Location.fromJson(Map<String, dynamic>.from(m)))
                  .toList();
              Location? selected;
              final stored = _prefs.getInt(selectedLocationKey);
              if (stored != null) {
                try {
                  selected = list.firstWhere((l) => l.locationId == stored);
                } catch (_) {
                  selected = null;
                }
              }
              state = state.copyWith(
                isLoading: false,
                locations: list,
                selected: selected ?? (list.isNotEmpty ? list.first : null),
                error: 'Offline: using cached locations.',
              );
              return;
            }
          } catch (_) {
            // fall-through to normal error
          }
        }

        // Last-resort: preserve stored selected location id so offline outbox flows can continue.
        final stored = _prefs.getInt(selectedLocationKey);
        if (stored != null && stored > 0) {
          state = state.copyWith(
            isLoading: false,
            selected: Location(locationId: stored, name: 'Location #$stored'),
            locations: const [],
            error: 'Offline: location list unavailable.',
          );
          return;
        }
      }
      state = state.copyWith(
        isLoading: false,
        error: ErrorHandler.message(e),
      );
    }
  }

  Future<void> select(Location location) async {
    state = state.copyWith(selected: location);
    await _prefs.setInt(selectedLocationKey, location.locationId);
  }
}

final locationNotifierProvider =
    StateNotifierProvider<LocationNotifier, LocationState>((ref) {
  final repo = ref.watch(locationRepositoryProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return LocationNotifier(repo, prefs, ref);
});
