import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/location_repository.dart';
import '../data/models.dart';
import '../../../core/api_client.dart';

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
  LocationNotifier(this._repository, this._prefs)
      : super(const LocationState());

  static const selectedLocationKey = 'selected_location_id';

  final LocationRepository _repository;
  final SharedPreferences _prefs;

  Future<void> load(int companyId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final list = await _repository.fetchLocations(companyId);
      Location? selected;
      final stored = _prefs.getInt(selectedLocationKey);
      if (stored != null) {
        try {
          selected =
              list.firstWhere((l) => l.locationId == stored);
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
      state = state.copyWith(isLoading: false, error: e.toString());
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
  return LocationNotifier(repo, prefs);
});
