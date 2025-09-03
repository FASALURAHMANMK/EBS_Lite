import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../dashboard/controllers/location_notifier.dart';
import 'models.dart';

class InventoryRepository {
  InventoryRepository(this._dio, this._ref);

  final Dio _dio;
  final Ref _ref;

  int? get _locationId => _ref.read(locationNotifierProvider).selected?.locationId;

  // Safely extract a List from API responses which may return
  // { data: [...] }, null, or a top-level list.
  List<dynamic> _extractList(Response res) {
    final body = res.data;
    if (body is List) return body;
    if (body is Map) {
      final value = body['data'];
      if (value is List) return value;
      return const [];
    }
    return const [];
  }

  Future<List<InventoryListItem>> getStock() async {
    final loc = _locationId;
    final res = await _dio.get(
      '/inventory/stock',
      queryParameters: loc != null ? {'location_id': loc} : null,
    );
    final data = _extractList(res);
    return data
        .map((e) => InventoryListItem.fromStockJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<InventoryListItem?> getStockForProduct(int productId) async {
    final loc = _locationId;
    final qp = <String, dynamic>{'product_id': productId};
    if (loc != null) qp['location_id'] = loc;
    final res = await _dio.get('/inventory/stock', queryParameters: qp);
    final data = _extractList(res);
    if (data.isEmpty) return null;
    return InventoryListItem.fromStockJson(data.first as Map<String, dynamic>);
  }

  Future<List<InventoryListItem>> searchProducts(String term) async {
    final loc = _locationId;
    final res = await _dio.get(
      '/pos/products',
      queryParameters: {
        'search': term,
        if (loc != null) 'location_id': loc,
      },
    );
    final data = _extractList(res);
    return data
        .map((e) => InventoryListItem.fromPOSJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<CategoryDto>> getCategories() async {
    final res = await _dio.get('/categories');
    final data = _extractList(res);
    return data
        .map((e) => CategoryDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CategoryDto> createCategory({required String name}) async {
    final res = await _dio.post('/categories', data: {'name': name});
    return CategoryDto.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<CategoryDto> updateCategory({required int id, required String name}) async {
    final res = await _dio.put('/categories/$id', data: {'name': name});
    return CategoryDto.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<void> deleteCategory(int id) async {
    await _dio.delete('/categories/$id');
  }

  Future<List<BrandDto>> getBrands() async {
    final res = await _dio.get('/brands');
    final data = _extractList(res);
    return data
        .map((e) => BrandDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<BrandDto> createBrand({required String name}) async {
    final res = await _dio.post('/brands', data: {'name': name});
    return BrandDto.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<BrandDto> updateBrand({required int id, required String name, bool? isActive}) async {
    final body = <String, dynamic>{'name': name};
    if (isActive != null) body['is_active'] = isActive;
    final res = await _dio.put('/brands/$id', data: body);
    return BrandDto.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<void> deleteBrand(int id) async {
    await _dio.delete('/brands/$id');
  }

  Future<List<UnitDto>> getUnits() async {
    final res = await _dio.get('/units');
    final data = _extractList(res);
    return data
        .map((e) => UnitDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ProductDto> getProduct(int id) async {
    final res = await _dio.get('/products/$id');
    return ProductDto.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<List<ProductAttributeDefinitionDto>> getAttributeDefinitions() async {
    final res = await _dio.get('/product-attribute-definitions');
    final data = _extractList(res);
    return data
        .map((e) => ProductAttributeDefinitionDto.fromJson(
            e as Map<String, dynamic>))
        .toList();
  }

  Future<ProductAttributeDefinitionDto> createAttributeDefinition({
    required String name,
    required String type,
    required bool isRequired,
    List<String>? options,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'type': type,
      'is_required': isRequired,
    };
    if (options != null && options.isNotEmpty) {
      // Backend expects JSON string for options (e.g., "[\"Red\",\"Blue\"]")
      body['options'] = jsonEncode(options);
    }
    final res = await _dio.post('/product-attribute-definitions', data: body);
    return ProductAttributeDefinitionDto.fromJson(
        res.data['data'] as Map<String, dynamic>);
  }

  Future<void> updateAttributeDefinition(
    int id, {
    String? name,
    String? type,
    bool? isRequired,
    List<String>? options,
    bool? isActive,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (type != null) body['type'] = type;
    if (isRequired != null) body['is_required'] = isRequired;
    if (options != null) body['options'] = jsonEncode(options);
    if (isActive != null) body['is_active'] = isActive;
    await _dio.put('/product-attribute-definitions/$id', data: body);
  }

  Future<void> deleteAttributeDefinition(int id) async {
    await _dio.delete('/product-attribute-definitions/$id');
  }

  Future<ProductDto> createProduct(CreateProductPayload payload) async {
    final res = await _dio.post('/products', data: payload.toJson());
    return ProductDto.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<ProductDto> updateProduct(ProductDto product) async {
    final res = await _dio.put('/products/${product.productId}', data: product.toUpdateJson());
    return ProductDto.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<void> deleteProduct(int id) async {
    await _dio.delete('/products/$id');
  }

  Future<void> adjustStock({
    required int productId,
    required double adjustment,
    required String reason,
  }) async {
    final loc = _locationId;
    final qp = <String, dynamic>{};
    if (loc != null) qp['location_id'] = loc;
    await _dio.post(
      '/inventory/stock-adjustment',
      queryParameters: qp.isEmpty ? null : qp,
      data: {
        'product_id': productId,
        'adjustment': adjustment,
        'reason': reason,
      },
    );
  }

  Future<List<StockAdjustmentDto>> getStockAdjustments() async {
    final loc = _locationId;
    final qp = <String, dynamic>{};
    if (loc != null) qp['location_id'] = loc;
    final res = await _dio.get(
      '/inventory/stock-adjustments',
      queryParameters: qp.isEmpty ? null : qp,
    );
    final data = _extractList(res);
    return data
        .map((e) => StockAdjustmentDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<StockAdjustmentDocumentDto> createStockAdjustmentDocument({
    required String reason,
    required List<Map<String, dynamic>> items,
  }) async {
    final loc = _locationId;
    final qp = <String, dynamic>{};
    if (loc != null) qp['location_id'] = loc;
    final res = await _dio.post(
      '/inventory/stock-adjustment-documents',
      queryParameters: qp.isEmpty ? null : qp,
      data: {
        'reason': reason,
        'items': items,
      },
    );
    final body = res.data is Map<String, dynamic> ? res.data['data'] : res.data;
    return StockAdjustmentDocumentDto.fromJson(body as Map<String, dynamic>);
  }

  Future<List<StockAdjustmentDocumentDto>> getStockAdjustmentDocuments() async {
    final loc = _locationId;
    final qp = <String, dynamic>{};
    if (loc != null) qp['location_id'] = loc;
    final res = await _dio.get(
      '/inventory/stock-adjustment-documents',
      queryParameters: qp.isEmpty ? null : qp,
    );
    final data = _extractList(res);
    return data
        .map((e) => StockAdjustmentDocumentDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<StockAdjustmentDocumentDto> getStockAdjustmentDocument(int id) async {
    final loc = _locationId;
    final qp = <String, dynamic>{};
    if (loc != null) qp['location_id'] = loc;
    final res = await _dio.get(
      '/inventory/stock-adjustment-documents/$id',
      queryParameters: qp.isEmpty ? null : qp,
    );
    final body = res.data is Map<String, dynamic> ? res.data['data'] : res.data;
    return StockAdjustmentDocumentDto.fromJson(body as Map<String, dynamic>);
  }
}

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return InventoryRepository(dio, ref);
});
