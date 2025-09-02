import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/inventory_repository.dart';
import '../data/models.dart';
import 'inventory_notifier.dart' show InventoryViewMode;

class CategoryState {
  final List<CategoryDto> items;
  final String query;
  final InventoryViewMode viewMode;
  final bool isLoading;
  final String? error;

  const CategoryState({
    this.items = const [],
    this.query = '',
    this.viewMode = InventoryViewMode.grid,
    this.isLoading = false,
    this.error,
  });

  CategoryState copyWith({
    List<CategoryDto>? items,
    String? query,
    InventoryViewMode? viewMode,
    bool? isLoading,
    String? error,
  }) {
    return CategoryState(
      items: items ?? this.items,
      query: query ?? this.query,
      viewMode: viewMode ?? this.viewMode,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class CategoryManagementNotifier extends StateNotifier<CategoryState> {
  CategoryManagementNotifier(this._repo) : super(const CategoryState());
  final InventoryRepository _repo;
  Timer? _debounce;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final cats = await _repo.getCategories();
      state = state.copyWith(isLoading: false, items: cats);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setViewMode(InventoryViewMode mode) {
    state = state.copyWith(viewMode: mode);
  }

  void setQuery(String q) {
    state = state.copyWith(query: q);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => {});
  }
}

final categoryManagementProvider =
    StateNotifierProvider<CategoryManagementNotifier, CategoryState>((ref) {
  final repo = ref.watch(inventoryRepositoryProvider);
  final notifier = CategoryManagementNotifier(repo);
  notifier.load();
  return notifier;
});

class BrandState {
  final List<BrandDto> items;
  final String query;
  final InventoryViewMode viewMode;
  final bool isLoading;
  final String? error;

  const BrandState({
    this.items = const [],
    this.query = '',
    this.viewMode = InventoryViewMode.grid,
    this.isLoading = false,
    this.error,
  });

  BrandState copyWith({
    List<BrandDto>? items,
    String? query,
    InventoryViewMode? viewMode,
    bool? isLoading,
    String? error,
  }) {
    return BrandState(
      items: items ?? this.items,
      query: query ?? this.query,
      viewMode: viewMode ?? this.viewMode,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class BrandManagementNotifier extends StateNotifier<BrandState> {
  BrandManagementNotifier(this._repo) : super(const BrandState());
  final InventoryRepository _repo;
  Timer? _debounce;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final brands = await _repo.getBrands();
      state = state.copyWith(isLoading: false, items: brands);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setViewMode(InventoryViewMode mode) {
    state = state.copyWith(viewMode: mode);
  }

  void setQuery(String q) {
    state = state.copyWith(query: q);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => {});
  }
}

final brandManagementProvider =
    StateNotifierProvider<BrandManagementNotifier, BrandState>((ref) {
  final repo = ref.watch(inventoryRepositoryProvider);
  final notifier = BrandManagementNotifier(repo);
  notifier.load();
  return notifier;
});

class AttributeState {
  final List<ProductAttributeDefinitionDto> items;
  final String query;
  final InventoryViewMode viewMode;
  final bool isLoading;
  final String? error;

  const AttributeState({
    this.items = const [],
    this.query = '',
    this.viewMode = InventoryViewMode.grid,
    this.isLoading = false,
    this.error,
  });

  AttributeState copyWith({
    List<ProductAttributeDefinitionDto>? items,
    String? query,
    InventoryViewMode? viewMode,
    bool? isLoading,
    String? error,
  }) {
    return AttributeState(
      items: items ?? this.items,
      query: query ?? this.query,
      viewMode: viewMode ?? this.viewMode,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AttributeManagementNotifier extends StateNotifier<AttributeState> {
  AttributeManagementNotifier(this._repo) : super(const AttributeState());
  final InventoryRepository _repo;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final defs = await _repo.getAttributeDefinitions();
      state = state.copyWith(isLoading: false, items: defs);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setViewMode(InventoryViewMode mode) {
    state = state.copyWith(viewMode: mode);
  }

  void setQuery(String q) {
    state = state.copyWith(query: q);
  }
}

final attributeManagementProvider =
    StateNotifierProvider<AttributeManagementNotifier, AttributeState>((ref) {
  final repo = ref.watch(inventoryRepositoryProvider);
  final notifier = AttributeManagementNotifier(repo);
  notifier.load();
  return notifier;
});
