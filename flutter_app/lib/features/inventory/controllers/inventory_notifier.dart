import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/inventory_repository.dart';
import '../data/models.dart';

enum InventoryViewMode { grid, list }

class InventoryState {
  final List<InventoryListItem> items;
  final List<CategoryDto> categories;
  final List<int> selectedCategoryIds;
  final String query;
  final InventoryViewMode viewMode;
  final bool onlyLowStock;
  final bool isLoading;
  final String? error;

  const InventoryState({
    this.items = const [],
    this.categories = const [],
    this.selectedCategoryIds = const [],
    this.query = '',
    this.viewMode = InventoryViewMode.grid,
    this.onlyLowStock = false,
    this.isLoading = false,
    this.error,
  });

  InventoryState copyWith({
    List<InventoryListItem>? items,
    List<CategoryDto>? categories,
    List<int>? selectedCategoryIds,
    String? query,
    InventoryViewMode? viewMode,
    bool? onlyLowStock,
    bool? isLoading,
    String? error,
  }) {
    return InventoryState(
      items: items ?? this.items,
      categories: categories ?? this.categories,
      selectedCategoryIds: selectedCategoryIds ?? this.selectedCategoryIds,
      query: query ?? this.query,
      viewMode: viewMode ?? this.viewMode,
      onlyLowStock: onlyLowStock ?? this.onlyLowStock,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class InventoryNotifier extends StateNotifier<InventoryState> {
  InventoryNotifier(this._repo) : super(const InventoryState());

  final InventoryRepository _repo;
  Timer? _debounce;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final cats = await _repo.getCategories();
      final items = await _repo.getStock();
      state = state.copyWith(
        isLoading: false,
        categories: cats,
        items: items,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setViewMode(InventoryViewMode mode) {
    state = state.copyWith(viewMode: mode);
  }

  void setOnlyLowStock(bool value) {
    state = state.copyWith(onlyLowStock: value);
  }

  void setCategories(List<int> ids) {
    state = state.copyWith(selectedCategoryIds: ids);
  }

  void setQuery(String q) {
    state = state.copyWith(query: q);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      await search();
    });
  }

  Future<void> refreshList() async {
    // Use stock list for default listing (includes stock & low-stock flag).
    final items = await _repo.getStock();
    state = state.copyWith(items: items);
  }

  Future<void> search() async {
    final q = state.query.trim();
    if (q.isEmpty) {
      await refreshList();
      return;
    }
    state = state.copyWith(isLoading: true, error: null);
    try {
      final items = await _repo.searchProducts(q);
      state = state.copyWith(isLoading: false, items: items);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final inventoryNotifierProvider =
    StateNotifierProvider<InventoryNotifier, InventoryState>((ref) {
  final repo = ref.watch(inventoryRepositoryProvider);
  final notifier = InventoryNotifier(repo);
  notifier.load();
  return notifier;
});
