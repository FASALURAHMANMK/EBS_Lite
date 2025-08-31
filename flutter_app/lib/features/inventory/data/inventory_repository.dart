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

  Future<List<InventoryListItem>> getStock() async {
    final loc = _locationId;
    final res = await _dio.get(
      '/inventory/stock',
      queryParameters: loc != null ? {'location_id': loc} : null,
    );
    final data = res.data['data'] as List<dynamic>;
    return data
        .map((e) => InventoryListItem.fromStockJson(e as Map<String, dynamic>))
        .toList();
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
    final data = res.data['data'] as List<dynamic>;
    return data
        .map((e) => InventoryListItem.fromPOSJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<CategoryDto>> getCategories() async {
    final res = await _dio.get('/categories');
    final data = res.data['data'] as List<dynamic>;
    return data
        .map((e) => CategoryDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<BrandDto>> getBrands() async {
    final res = await _dio.get('/brands');
    final data = res.data['data'] as List<dynamic>;
    return data
        .map((e) => BrandDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<UnitDto>> getUnits() async {
    final res = await _dio.get('/units');
    final data = res.data['data'] as List<dynamic>;
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
    final data = res.data['data'] as List<dynamic>;
    return data
        .map((e) => ProductAttributeDefinitionDto.fromJson(
            e as Map<String, dynamic>))
        .toList();
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
}

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return InventoryRepository(dio, ref);
});
