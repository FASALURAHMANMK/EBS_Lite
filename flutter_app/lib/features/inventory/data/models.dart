import 'dart:convert';

class InventoryListItem {
  final int productId;
  final String name;
  final String? sku;
  final String? categoryName;
  final String? brandName;
  final String? unitSymbol;
  final int reorderLevel;
  final double stock;
  final bool isLowStock;
  final double? price; // may be null when sourced from stock API

  const InventoryListItem({
    required this.productId,
    required this.name,
    this.sku,
    this.categoryName,
    this.brandName,
    this.unitSymbol,
    required this.reorderLevel,
    required this.stock,
    required this.isLowStock,
    this.price,
  });

  factory InventoryListItem.fromStockJson(Map<String, dynamic> json) =>
      InventoryListItem(
        productId: json['product_id'] as int,
        name: json['product_name'] as String? ?? '',
        sku: json['product_sku'] as String?,
        categoryName: json['category_name'] as String?,
        brandName: json['brand_name'] as String?,
        unitSymbol: json['unit_symbol'] as String?,
        reorderLevel: json['reorder_level'] as int? ?? 0,
        stock: (json['quantity'] as num?)?.toDouble() ?? 0,
        isLowStock: json['is_low_stock'] as bool? ?? false,
        price: null,
      );

  factory InventoryListItem.fromPOSJson(Map<String, dynamic> json) =>
      InventoryListItem(
        productId: json['product_id'] as int,
        name: json['name'] as String? ?? '',
        sku: json['sku']
            as String?, // POS response may not include; okay if null
        categoryName: json['category_name'] as String?,
        brandName: null,
        unitSymbol: null,
        reorderLevel: 0,
        stock: (json['stock'] as num?)?.toDouble() ?? 0,
        isLowStock: false,
        price: (json['price'] as num?)?.toDouble(),
      );
}

class CategoryDto {
  final int categoryId;
  final String name;
  final int? parentId;
  final bool isActive;

  CategoryDto({
    required this.categoryId,
    required this.name,
    this.parentId,
    this.isActive = true,
  });

  factory CategoryDto.fromJson(Map<String, dynamic> json) => CategoryDto(
        categoryId: json['category_id'] as int,
        name: json['name'] as String? ?? '',
        parentId: json['parent_id'] as int?,
        isActive: json['is_active'] as bool? ?? true,
      );
}

class BrandDto {
  final int brandId;
  final String name;
  final bool isActive;

  BrandDto({required this.brandId, required this.name, this.isActive = true});

  factory BrandDto.fromJson(Map<String, dynamic> json) => BrandDto(
        brandId: json['brand_id'] as int,
        name: json['name'] as String? ?? '',
        isActive: json['is_active'] as bool? ?? true,
      );
}

class UnitDto {
  final int unitId;
  final String name;
  final String? symbol;
  final int? baseUnitId;
  final double? conversionFactor;

  UnitDto({
    required this.unitId,
    required this.name,
    this.symbol,
    this.baseUnitId,
    this.conversionFactor,
  });

  factory UnitDto.fromJson(Map<String, dynamic> json) => UnitDto(
        unitId: json['unit_id'] as int,
        name: json['name'] as String? ?? '',
        symbol: json['symbol'] as String?,
        baseUnitId: json['base_unit_id'] as int?,
        conversionFactor: (json['conversion_factor'] as num?)?.toDouble(),
      );
}

class ProductBarcodeDto {
  final int? barcodeId;
  final String barcode;
  final int? packSize; // optional
  final double? costPrice;
  final double? sellingPrice;
  final bool isPrimary;

  ProductBarcodeDto({
    this.barcodeId,
    required this.barcode,
    this.packSize,
    this.costPrice,
    this.sellingPrice,
    required this.isPrimary,
  });

  factory ProductBarcodeDto.fromJson(Map<String, dynamic> json) =>
      ProductBarcodeDto(
        barcodeId: json['barcode_id'] as int?,
        barcode: json['barcode'] as String? ?? '',
        packSize: json['pack_size'] as int?,
        costPrice: (json['cost_price'] as num?)?.toDouble(),
        sellingPrice: (json['selling_price'] as num?)?.toDouble(),
        isPrimary: json['is_primary'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'barcode': barcode,
        if (packSize != null) 'pack_size': packSize,
        if (costPrice != null) 'cost_price': costPrice,
        if (sellingPrice != null) 'selling_price': sellingPrice,
        'is_primary': isPrimary,
      };
}

class ProductDto {
  final int productId;
  final int companyId;
  final int? categoryId;
  final int? brandId;
  final int? unitId;
  final String name;
  final String? sku;
  final String? description;
  final double? costPrice;
  final double? sellingPrice;
  final int reorderLevel;
  final double? weight;
  final String? dimensions;
  final bool isSerialized;
  final bool isActive;
  final List<ProductBarcodeDto> barcodes;
  final Map<int, String>? attributes;

  ProductDto({
    required this.productId,
    required this.companyId,
    this.categoryId,
    this.brandId,
    this.unitId,
    required this.name,
    this.sku,
    this.description,
    this.costPrice,
    this.sellingPrice,
    required this.reorderLevel,
    this.weight,
    this.dimensions,
    required this.isSerialized,
    required this.isActive,
    required this.barcodes,
    this.attributes,
  });

  factory ProductDto.fromJson(Map<String, dynamic> json) => ProductDto(
        productId: json['product_id'] as int,
        companyId: json['company_id'] as int,
        categoryId: json['category_id'] as int?,
        brandId: json['brand_id'] as int?,
        unitId: json['unit_id'] as int?,
        name: json['name'] as String? ?? '',
        sku: json['sku'] as String?,
        description: json['description'] as String?,
        costPrice: (json['cost_price'] as num?)?.toDouble(),
        sellingPrice: (json['selling_price'] as num?)?.toDouble(),
        reorderLevel: json['reorder_level'] as int? ?? 0,
        weight: (json['weight'] as num?)?.toDouble(),
        dimensions: json['dimensions'] as String?,
        isSerialized: json['is_serialized'] as bool? ?? false,
        isActive: json['is_active'] as bool? ?? true,
        barcodes: (json['barcodes'] as List?)
                ?.map((e) =>
                    ProductBarcodeDto.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        attributes: (json['attributes'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(int.tryParse(k) ?? -1, v.toString()),
        ),
      );

  Map<String, dynamic> toUpdateJson() => {
        if (categoryId != null) 'category_id': categoryId,
        if (brandId != null) 'brand_id': brandId,
        if (unitId != null) 'unit_id': unitId,
        'name': name,
        if (sku != null) 'sku': sku,
        if (description != null) 'description': description,
        if (costPrice != null) 'cost_price': costPrice,
        if (sellingPrice != null) 'selling_price': sellingPrice,
        'reorder_level': reorderLevel,
        if (weight != null) 'weight': weight,
        if (dimensions != null) 'dimensions': dimensions,
        'is_serialized': isSerialized,
        'is_active': isActive,
        if (barcodes.isNotEmpty)
          'barcodes': barcodes.map((b) => b.toJson()).toList(),
        if (attributes != null && attributes!.isNotEmpty)
          'attributes': attributes!.map((k, v) => MapEntry(k.toString(), v)),
      };
}

class CreateProductPayload {
  final int? categoryId;
  final int? brandId;
  final int? unitId;
  final String name;
  final String? sku;
  final String? description;
  final double? costPrice;
  final double? sellingPrice;
  final int reorderLevel;
  final double? weight;
  final String? dimensions;
  final bool isSerialized;
  final List<ProductBarcodeDto> barcodes;
  final Map<int, String>? attributes;

  CreateProductPayload({
    this.categoryId,
    this.brandId,
    this.unitId,
    required this.name,
    this.sku,
    this.description,
    this.costPrice,
    this.sellingPrice,
    this.reorderLevel = 0,
    this.weight,
    this.dimensions,
    this.isSerialized = false,
    required this.barcodes,
    this.attributes,
  });

  Map<String, dynamic> toJson() => {
        if (categoryId != null) 'category_id': categoryId,
        if (brandId != null) 'brand_id': brandId,
        if (unitId != null) 'unit_id': unitId,
        'name': name,
        if (sku != null) 'sku': sku,
        if (description != null) 'description': description,
        if (costPrice != null) 'cost_price': costPrice,
        if (sellingPrice != null) 'selling_price': sellingPrice,
        'reorder_level': reorderLevel,
        if (weight != null) 'weight': weight,
        if (dimensions != null) 'dimensions': dimensions,
        'is_serialized': isSerialized,
        'barcodes': barcodes.map((e) => e.toJson()).toList(),
        if (attributes != null && attributes!.isNotEmpty)
          'attributes': attributes!.map((k, v) => MapEntry(k.toString(), v)),
      };
}

class ProductAttributeDefinitionDto {
  final int attributeId;
  final String name;
  final String type; // TEXT, NUMBER, DATE, BOOLEAN, SELECT
  final bool isRequired;
  final List<String>? options; // for SELECT

  ProductAttributeDefinitionDto({
    required this.attributeId,
    required this.name,
    required this.type,
    required this.isRequired,
    this.options,
  });

  factory ProductAttributeDefinitionDto.fromJson(Map<String, dynamic> json) {
    List<String>? opts;
    final raw = json['options'];
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = raw.startsWith('[')
            ? raw
            : raw; // backend stores JSON string; treat as JSON array string
        final list =
            (jsonDecode(decoded) as List).map((e) => e.toString()).toList();
        opts = list;
      } catch (_) {
        opts = null;
      }
    }
    return ProductAttributeDefinitionDto(
      attributeId: json['attribute_id'] as int,
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? 'TEXT',
      isRequired: json['is_required'] as bool? ?? false,
      options: opts,
    );
  }
}
