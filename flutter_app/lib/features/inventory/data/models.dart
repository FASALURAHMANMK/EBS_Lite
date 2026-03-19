import 'dart:convert';

class InventoryListItem {
  final int productId;
  final int? comboProductId;
  final int? barcodeId;
  final String name;
  final String? sku;
  final String? variantName;
  final int? categoryId;
  final String? categoryName;
  final String? brandName;
  final String? unitSymbol;
  final int reorderLevel;
  final double stock;
  final bool isLowStock;
  final String trackingType;
  final double? price; // may be null when sourced from stock API
  final String? primaryStorage;
  final bool isVirtualCombo;

  const InventoryListItem({
    required this.productId,
    this.comboProductId,
    this.barcodeId,
    required this.name,
    this.sku,
    this.variantName,
    this.categoryId,
    this.categoryName,
    this.brandName,
    this.unitSymbol,
    required this.reorderLevel,
    required this.stock,
    required this.isLowStock,
    this.trackingType = 'VARIANT',
    this.price,
    this.primaryStorage,
    this.isVirtualCombo = false,
  });

  factory InventoryListItem.fromStockJson(Map<String, dynamic> json) =>
      InventoryListItem(
        productId: json['product_id'] as int,
        barcodeId: json['barcode_id'] as int?,
        name: json['product_name'] as String? ?? '',
        sku: json['product_sku'] as String?,
        variantName: json['variant_name'] as String?,
        categoryId: json['category_id'] as int?,
        categoryName: json['category_name'] as String?,
        brandName: json['brand_name'] as String?,
        unitSymbol: json['unit_symbol'] as String?,
        reorderLevel: json['reorder_level'] as int? ?? 0,
        stock: (json['quantity'] as num?)?.toDouble() ?? 0,
        isLowStock: json['is_low_stock'] as bool? ?? false,
        trackingType: json['tracking_type'] as String? ?? 'VARIANT',
        price: null,
        primaryStorage: json['primary_storage'] as String?,
        isVirtualCombo: json['is_virtual_combo'] as bool? ?? false,
      );

  factory InventoryListItem.fromPOSJson(Map<String, dynamic> json) =>
      InventoryListItem(
        productId: json['product_id'] as int,
        comboProductId: json['combo_product_id'] as int?,
        barcodeId: json['barcode_id'] as int?,
        name: json['name'] as String? ?? '',
        sku: json['sku']
            as String?, // POS response may not include; okay if null
        variantName: json['variant_name'] as String?,
        categoryId: json['category_id'] as int?,
        categoryName: json['category_name'] as String?,
        brandName: null,
        unitSymbol: null,
        reorderLevel: 0,
        stock: (json['stock'] as num?)?.toDouble() ?? 0,
        isLowStock: false,
        trackingType: json['tracking_type'] as String? ?? 'VARIANT',
        price: (json['price'] as num?)?.toDouble(),
        primaryStorage: json['primary_storage'] as String?,
        isVirtualCombo: json['is_virtual_combo'] as bool? ?? false,
      );
}

class ProductStorageAssignmentDto {
  final int storageAssignmentId;
  final int productId;
  final int locationId;
  final int barcodeId;
  final String storageType;
  final String storageLabel;
  final String? notes;
  final bool isPrimary;
  final int sortOrder;
  final String? locationName;
  final String? barcode;
  final String? variantName;

  const ProductStorageAssignmentDto({
    required this.storageAssignmentId,
    required this.productId,
    required this.locationId,
    required this.barcodeId,
    required this.storageType,
    required this.storageLabel,
    this.notes,
    required this.isPrimary,
    required this.sortOrder,
    this.locationName,
    this.barcode,
    this.variantName,
  });

  factory ProductStorageAssignmentDto.fromJson(Map<String, dynamic> json) =>
      ProductStorageAssignmentDto(
        storageAssignmentId: json['storage_assignment_id'] as int? ?? 0,
        productId: json['product_id'] as int? ?? 0,
        locationId: json['location_id'] as int? ?? 0,
        barcodeId: json['barcode_id'] as int? ?? 0,
        storageType: json['storage_type'] as String? ?? '',
        storageLabel: json['storage_label'] as String? ?? '',
        notes: json['notes'] as String?,
        isPrimary: json['is_primary'] as bool? ?? false,
        sortOrder: json['sort_order'] as int? ?? 0,
        locationName: json['location_name'] as String?,
        barcode: json['barcode'] as String?,
        variantName: json['variant_name'] as String?,
      );
}

class ProductStorageAssignmentPayload {
  final int? storageAssignmentId;
  final int? barcodeId;
  final String? barcode;
  final String storageType;
  final String storageLabel;
  final String? notes;
  final bool isPrimary;
  final int sortOrder;

  const ProductStorageAssignmentPayload({
    this.storageAssignmentId,
    this.barcodeId,
    this.barcode,
    required this.storageType,
    required this.storageLabel,
    this.notes,
    required this.isPrimary,
    required this.sortOrder,
  });

  Map<String, dynamic> toJson() => {
        if (storageAssignmentId != null)
          'storage_assignment_id': storageAssignmentId,
        if (barcodeId != null) 'barcode_id': barcodeId,
        if (barcode != null && barcode!.trim().isNotEmpty) 'barcode': barcode,
        'storage_type': storageType,
        'storage_label': storageLabel,
        if (notes != null && notes!.trim().isNotEmpty) 'notes': notes,
        'is_primary': isPrimary,
        'sort_order': sortOrder,
      };
}

class ComboProductComponentDto {
  final int comboProductItemId;
  final int comboProductId;
  final int productId;
  final int barcodeId;
  final double quantity;
  final int sortOrder;
  final String productName;
  final String? productSku;
  final String? barcode;
  final String? variantName;
  final String trackingType;
  final bool isSerialized;
  final String? unitSymbol;
  final double? availableStock;

  const ComboProductComponentDto({
    required this.comboProductItemId,
    required this.comboProductId,
    required this.productId,
    required this.barcodeId,
    required this.quantity,
    required this.sortOrder,
    required this.productName,
    this.productSku,
    this.barcode,
    this.variantName,
    this.trackingType = 'VARIANT',
    this.isSerialized = false,
    this.unitSymbol,
    this.availableStock,
  });

  factory ComboProductComponentDto.fromJson(Map<String, dynamic> json) =>
      ComboProductComponentDto(
        comboProductItemId: json['combo_product_item_id'] as int? ?? 0,
        comboProductId: json['combo_product_id'] as int? ?? 0,
        productId: json['product_id'] as int? ?? 0,
        barcodeId: json['barcode_id'] as int? ?? 0,
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
        sortOrder: json['sort_order'] as int? ?? 0,
        productName: json['product_name'] as String? ?? '',
        productSku: json['product_sku'] as String?,
        barcode: json['barcode'] as String?,
        variantName: json['variant_name'] as String?,
        trackingType: json['tracking_type'] as String? ?? 'VARIANT',
        isSerialized: json['is_serialized'] as bool? ?? false,
        unitSymbol: json['unit_symbol'] as String?,
        availableStock: (json['available_stock'] as num?)?.toDouble(),
      );
}

class ComboProductDto {
  final int comboProductId;
  final int companyId;
  final String name;
  final String? sku;
  final String barcode;
  final double sellingPrice;
  final int taxId;
  final String? notes;
  final bool isActive;
  final double? availableStock;
  final List<ComboProductComponentDto> components;

  const ComboProductDto({
    required this.comboProductId,
    required this.companyId,
    required this.name,
    this.sku,
    required this.barcode,
    required this.sellingPrice,
    required this.taxId,
    this.notes,
    required this.isActive,
    this.availableStock,
    this.components = const [],
  });

  factory ComboProductDto.fromJson(Map<String, dynamic> json) =>
      ComboProductDto(
        comboProductId: json['combo_product_id'] as int? ?? 0,
        companyId: json['company_id'] as int? ?? 0,
        name: json['name'] as String? ?? '',
        sku: json['sku'] as String?,
        barcode: json['barcode'] as String? ?? '',
        sellingPrice: (json['selling_price'] as num?)?.toDouble() ?? 0,
        taxId: json['tax_id'] as int? ?? 0,
        notes: json['notes'] as String?,
        isActive: json['is_active'] as bool? ?? true,
        availableStock: (json['available_stock'] as num?)?.toDouble(),
        components: (json['components'] as List? ?? const [])
            .map((e) =>
                ComboProductComponentDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class ComboProductComponentPayload {
  final int productId;
  final int barcodeId;
  final double quantity;
  final int sortOrder;

  const ComboProductComponentPayload({
    required this.productId,
    required this.barcodeId,
    required this.quantity,
    required this.sortOrder,
  });

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'barcode_id': barcodeId,
        'quantity': quantity,
        'sort_order': sortOrder,
      };
}

class ComboProductPayload {
  final String name;
  final String? sku;
  final String barcode;
  final double sellingPrice;
  final int taxId;
  final String? notes;
  final bool isActive;
  final List<ComboProductComponentPayload> components;

  const ComboProductPayload({
    required this.name,
    this.sku,
    required this.barcode,
    required this.sellingPrice,
    required this.taxId,
    this.notes,
    required this.isActive,
    required this.components,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        if (sku != null && sku!.trim().isNotEmpty) 'sku': sku,
        'barcode': barcode,
        'selling_price': sellingPrice,
        'tax_id': taxId,
        if (notes != null && notes!.trim().isNotEmpty) 'notes': notes,
        'is_active': isActive,
        'components': components.map((e) => e.toJson()).toList(),
      };
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
  final String? variantName;
  final Map<String, dynamic>? variantAttributes;
  final bool isActive;

  ProductBarcodeDto({
    this.barcodeId,
    required this.barcode,
    this.packSize,
    this.costPrice,
    this.sellingPrice,
    required this.isPrimary,
    this.variantName,
    this.variantAttributes,
    this.isActive = true,
  });

  factory ProductBarcodeDto.fromJson(Map<String, dynamic> json) =>
      ProductBarcodeDto(
        barcodeId: json['barcode_id'] as int?,
        barcode: json['barcode'] as String? ?? '',
        packSize: json['pack_size'] as int?,
        costPrice: (json['cost_price'] as num?)?.toDouble(),
        sellingPrice: (json['selling_price'] as num?)?.toDouble(),
        isPrimary: json['is_primary'] as bool? ?? false,
        variantName: json['variant_name'] as String?,
        variantAttributes:
            (json['variant_attributes'] as Map?)?.cast<String, dynamic>(),
        isActive: json['is_active'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'barcode': barcode,
        if (packSize != null) 'pack_size': packSize,
        if (costPrice != null) 'cost_price': costPrice,
        if (sellingPrice != null) 'selling_price': sellingPrice,
        'is_primary': isPrimary,
        if (variantName != null) 'variant_name': variantName,
        if (variantAttributes != null && variantAttributes!.isNotEmpty)
          'variant_attributes': variantAttributes,
        'is_active': isActive,
      };
}

class StockAdjustmentDto {
  final int adjustmentId;
  final int locationId;
  final int productId;
  final double adjustment;
  final String? reason;
  final int? createdBy;
  final DateTime? createdAt;

  StockAdjustmentDto({
    required this.adjustmentId,
    required this.locationId,
    required this.productId,
    required this.adjustment,
    this.reason,
    this.createdBy,
    this.createdAt,
  });

  factory StockAdjustmentDto.fromJson(Map<String, dynamic> json) =>
      StockAdjustmentDto(
        adjustmentId: json['adjustment_id'] as int? ?? json['id'] as int? ?? 0,
        locationId: json['location_id'] as int? ?? 0,
        productId: json['product_id'] as int? ?? 0,
        adjustment: (json['adjustment'] as num?)?.toDouble() ?? 0,
        reason: json['reason'] as String?,
        createdBy: json['created_by'] as int?,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
      );
}

class StockAdjustmentDocumentItemDto {
  final int itemId;
  final int documentId;
  final int productId;
  final int? barcodeId;
  final double adjustment;
  final List<String> serialNumbers;
  final List<InventoryBatchAllocationDto> batchAllocations;

  StockAdjustmentDocumentItemDto({
    required this.itemId,
    required this.documentId,
    required this.productId,
    this.barcodeId,
    required this.adjustment,
    this.serialNumbers = const [],
    this.batchAllocations = const [],
  });

  factory StockAdjustmentDocumentItemDto.fromJson(Map<String, dynamic> json) =>
      StockAdjustmentDocumentItemDto(
        itemId: json['item_id'] as int? ?? 0,
        documentId: json['document_id'] as int? ?? 0,
        productId: json['product_id'] as int? ?? 0,
        barcodeId: json['barcode_id'] as int?,
        adjustment: (json['adjustment'] as num?)?.toDouble() ?? 0,
        serialNumbers: (json['serial_numbers'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        batchAllocations: (json['batch_allocations'] as List?)
                ?.map((e) => InventoryBatchAllocationDto.fromJson(
                    e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

class StockAdjustmentDocumentDto {
  final int documentId;
  final String documentNumber;
  final int locationId;
  final String? reason;
  final int? createdBy;
  final DateTime? createdAt;
  final List<StockAdjustmentDocumentItemDto> items;

  StockAdjustmentDocumentDto({
    required this.documentId,
    required this.documentNumber,
    required this.locationId,
    this.reason,
    this.createdBy,
    this.createdAt,
    this.items = const [],
  });

  factory StockAdjustmentDocumentDto.fromJson(Map<String, dynamic> json) =>
      StockAdjustmentDocumentDto(
        documentId: json['document_id'] as int? ?? 0,
        documentNumber: json['document_number'] as String? ?? '',
        locationId: json['location_id'] as int? ?? 0,
        reason: json['reason'] as String?,
        createdBy: json['created_by'] as int?,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
        items: (json['items'] as List?)
                ?.map((e) => StockAdjustmentDocumentItemDto.fromJson(
                    e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

class ProductTransactionDto {
  final String
      type; // SALE, PURCHASE, SALE_RETURN, PURCHASE_RETURN, ADJUSTMENT, TRANSFER_IN, TRANSFER_OUT
  final DateTime? occurredAt;
  final String reference;
  final double quantity;
  final int locationId;
  final String? locationName;
  final String? partnerName;
  final String
      entity; // sale, purchase, stock_adjustment, transfer, sale_return, purchase_return
  final int entityId;
  final String? notes;

  ProductTransactionDto({
    required this.type,
    required this.occurredAt,
    required this.reference,
    required this.quantity,
    required this.locationId,
    this.locationName,
    this.partnerName,
    required this.entity,
    required this.entityId,
    this.notes,
  });

  factory ProductTransactionDto.fromJson(Map<String, dynamic> json) =>
      ProductTransactionDto(
        type: json['type'] as String? ?? '',
        occurredAt: json['occurred_at'] != null
            ? DateTime.tryParse(json['occurred_at'] as String)
            : null,
        reference: json['reference'] as String? ?? '',
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
        locationId: json['location_id'] as int? ?? 0,
        locationName: json['location_name'] as String?,
        partnerName: json['partner_name'] as String?,
        entity: json['entity'] as String? ?? '',
        entityId: json['entity_id'] as int? ?? 0,
        notes: json['notes'] as String?,
      );
}

class ProductDto {
  final int productId;
  final int companyId;
  final String itemType;
  final int? categoryId;
  final int? brandId;
  final int? unitId; // stock keeping UOM
  final int? purchaseUnitId;
  final int? sellingUnitId;
  final String purchaseUomMode;
  final String sellingUomMode;
  final double purchaseToStockFactor;
  final double sellingToStockFactor;
  final bool isWeighable;
  final int taxId;
  final String name;
  final String? sku;
  final String? description;
  final double? costPrice;
  final double? sellingPrice;
  final int reorderLevel;
  final double? weight;
  final String? dimensions;
  final bool isSerialized;
  final String trackingType;
  final bool isActive;
  final List<ProductBarcodeDto> barcodes;
  final Map<int, String>? attributes;
  final int? defaultSupplierId;

  ProductDto({
    required this.productId,
    required this.companyId,
    this.itemType = 'PRODUCT',
    this.categoryId,
    this.brandId,
    this.unitId,
    this.purchaseUnitId,
    this.sellingUnitId,
    this.purchaseUomMode = 'LOOSE',
    this.sellingUomMode = 'LOOSE',
    this.purchaseToStockFactor = 1.0,
    this.sellingToStockFactor = 1.0,
    this.isWeighable = false,
    required this.taxId,
    required this.name,
    this.sku,
    this.description,
    this.costPrice,
    this.sellingPrice,
    required this.reorderLevel,
    this.weight,
    this.dimensions,
    required this.isSerialized,
    this.trackingType = 'VARIANT',
    required this.isActive,
    required this.barcodes,
    this.attributes,
    this.defaultSupplierId,
  });

  factory ProductDto.fromJson(Map<String, dynamic> json) => ProductDto(
        productId: json['product_id'] as int,
        companyId: json['company_id'] as int,
        itemType: (json['item_type'] as String? ?? 'PRODUCT').toUpperCase(),
        categoryId: json['category_id'] as int?,
        brandId: json['brand_id'] as int?,
        unitId: json['unit_id'] as int?,
        purchaseUnitId: json['purchase_unit_id'] as int?,
        sellingUnitId: json['selling_unit_id'] as int?,
        purchaseUomMode: json['purchase_uom_mode'] as String? ?? 'LOOSE',
        sellingUomMode: json['selling_uom_mode'] as String? ?? 'LOOSE',
        purchaseToStockFactor:
            (json['purchase_to_stock_factor'] as num?)?.toDouble() ?? 1.0,
        sellingToStockFactor:
            (json['selling_to_stock_factor'] as num?)?.toDouble() ?? 1.0,
        isWeighable: json['is_weighable'] as bool? ?? false,
        taxId: json['tax_id'] as int? ?? 0,
        name: json['name'] as String? ?? '',
        sku: json['sku'] as String?,
        description: json['description'] as String?,
        costPrice: (json['cost_price'] as num?)?.toDouble(),
        sellingPrice: (json['selling_price'] as num?)?.toDouble(),
        reorderLevel: json['reorder_level'] as int? ?? 0,
        weight: (json['weight'] as num?)?.toDouble(),
        dimensions: json['dimensions'] as String?,
        isSerialized: json['is_serialized'] as bool? ?? false,
        trackingType: json['tracking_type'] as String? ?? 'VARIANT',
        isActive: json['is_active'] as bool? ?? true,
        barcodes: (json['barcodes'] as List?)
                ?.map((e) =>
                    ProductBarcodeDto.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        attributes: () {
          final raw = json['attributes'];
          if (raw == null) return null;
          if (raw is Map<String, dynamic>) {
            return raw
                .map((k, v) => MapEntry(int.tryParse(k) ?? -1, v.toString()));
          }
          if (raw is List) {
            final map = <int, String>{};
            for (final e in raw) {
              if (e is Map<String, dynamic>) {
                final id = e['attribute_id'];
                final val = e['value'];
                if (id is int && val != null) {
                  map[id] = val.toString();
                }
              }
            }
            return map.isEmpty ? null : map;
          }
          return null;
        }(),
        defaultSupplierId: json['default_supplier_id'] as int?,
      );

  Map<String, dynamic> toUpdateJson() => {
        'item_type': itemType,
        if (categoryId != null) 'category_id': categoryId,
        if (brandId != null) 'brand_id': brandId,
        if (unitId != null) 'unit_id': unitId,
        if (purchaseUnitId != null) 'purchase_unit_id': purchaseUnitId,
        if (sellingUnitId != null) 'selling_unit_id': sellingUnitId,
        'purchase_uom_mode': purchaseUomMode,
        'selling_uom_mode': sellingUomMode,
        'purchase_to_stock_factor': purchaseToStockFactor,
        'selling_to_stock_factor': sellingToStockFactor,
        'is_weighable': isWeighable,
        'tax_id': taxId,
        'name': name,
        if (sku != null) 'sku': sku,
        if (description != null) 'description': description,
        if (costPrice != null) 'cost_price': costPrice,
        if (sellingPrice != null) 'selling_price': sellingPrice,
        'reorder_level': reorderLevel,
        if (weight != null) 'weight': weight,
        if (dimensions != null) 'dimensions': dimensions,
        'is_serialized': isSerialized,
        'tracking_type': trackingType,
        'is_active': isActive,
        if (barcodes.isNotEmpty)
          'barcodes': barcodes.map((b) => b.toJson()).toList(),
        if (attributes != null && attributes!.isNotEmpty)
          'attributes': attributes!.map((k, v) => MapEntry(k.toString(), v)),
        if (defaultSupplierId != null) 'default_supplier_id': defaultSupplierId,
      };
}

class CreateProductPayload {
  final String itemType;
  final int? categoryId;
  final int? brandId;
  final int? unitId; // stock keeping UOM
  final int? purchaseUnitId;
  final int? sellingUnitId;
  final String purchaseUomMode;
  final String sellingUomMode;
  final double purchaseToStockFactor;
  final double sellingToStockFactor;
  final bool isWeighable;
  final int taxId;
  final String name;
  final String? sku;
  final String? description;
  final double? costPrice;
  final double? sellingPrice;
  final int reorderLevel;
  final double? weight;
  final String? dimensions;
  final bool isSerialized;
  final String trackingType;
  final List<ProductBarcodeDto> barcodes;
  final Map<int, String>? attributes;
  final int? defaultSupplierId;

  CreateProductPayload({
    this.itemType = 'PRODUCT',
    this.categoryId,
    this.brandId,
    this.unitId,
    this.purchaseUnitId,
    this.sellingUnitId,
    this.purchaseUomMode = 'LOOSE',
    this.sellingUomMode = 'LOOSE',
    this.purchaseToStockFactor = 1.0,
    this.sellingToStockFactor = 1.0,
    this.isWeighable = false,
    required this.taxId,
    required this.name,
    this.sku,
    this.description,
    this.costPrice,
    this.sellingPrice,
    this.reorderLevel = 0,
    this.weight,
    this.dimensions,
    this.isSerialized = false,
    this.trackingType = 'VARIANT',
    required this.barcodes,
    this.attributes,
    this.defaultSupplierId,
  });

  Map<String, dynamic> toJson() => {
        'item_type': itemType,
        if (categoryId != null) 'category_id': categoryId,
        if (brandId != null) 'brand_id': brandId,
        if (unitId != null) 'unit_id': unitId,
        if (purchaseUnitId != null) 'purchase_unit_id': purchaseUnitId,
        if (sellingUnitId != null) 'selling_unit_id': sellingUnitId,
        'purchase_uom_mode': purchaseUomMode,
        'selling_uom_mode': sellingUomMode,
        'purchase_to_stock_factor': purchaseToStockFactor,
        'selling_to_stock_factor': sellingToStockFactor,
        'is_weighable': isWeighable,
        'tax_id': taxId,
        'name': name,
        if (sku != null) 'sku': sku,
        if (description != null) 'description': description,
        if (costPrice != null) 'cost_price': costPrice,
        if (sellingPrice != null) 'selling_price': sellingPrice,
        'reorder_level': reorderLevel,
        if (weight != null) 'weight': weight,
        if (dimensions != null) 'dimensions': dimensions,
        'is_serialized': isSerialized,
        'tracking_type': trackingType,
        'barcodes': barcodes.map((e) => e.toJson()).toList(),
        if (attributes != null && attributes!.isNotEmpty)
          'attributes': attributes!.map((k, v) => MapEntry(k.toString(), v)),
        if (defaultSupplierId != null) 'default_supplier_id': defaultSupplierId,
      };
}

class AssetCategoryDto {
  final int categoryId;
  final int companyId;
  final String name;
  final String? description;
  final int? ledgerAccountId;
  final String? ledgerCode;
  final String? ledgerName;
  final bool isActive;

  const AssetCategoryDto({
    required this.categoryId,
    required this.companyId,
    required this.name,
    this.description,
    this.ledgerAccountId,
    this.ledgerCode,
    this.ledgerName,
    this.isActive = true,
  });

  String get ledgerDisplay {
    final code = (ledgerCode ?? '').trim();
    final name = (ledgerName ?? '').trim();
    if (code.isEmpty && name.isEmpty) return 'Default fixed asset ledger';
    if (code.isEmpty) return name;
    if (name.isEmpty) return code;
    return '$code $name';
  }

  factory AssetCategoryDto.fromJson(Map<String, dynamic> json) =>
      AssetCategoryDto(
        categoryId: json['category_id'] as int? ?? 0,
        companyId: json['company_id'] as int? ?? 0,
        name: json['name'] as String? ?? '',
        description: json['description'] as String?,
        ledgerAccountId: json['ledger_account_id'] as int?,
        ledgerCode: json['ledger_code'] as String?,
        ledgerName: json['ledger_name'] as String?,
        isActive: json['is_active'] as bool? ?? true,
      );
}

class ConsumableCategoryDto {
  final int categoryId;
  final int companyId;
  final String name;
  final String? description;
  final int? ledgerAccountId;
  final String? ledgerCode;
  final String? ledgerName;
  final bool isActive;

  const ConsumableCategoryDto({
    required this.categoryId,
    required this.companyId,
    required this.name,
    this.description,
    this.ledgerAccountId,
    this.ledgerCode,
    this.ledgerName,
    this.isActive = true,
  });

  String get ledgerDisplay {
    final code = (ledgerCode ?? '').trim();
    final name = (ledgerName ?? '').trim();
    if (code.isEmpty && name.isEmpty) return 'Default consumables expense';
    if (code.isEmpty) return name;
    if (name.isEmpty) return code;
    return '$code $name';
  }

  factory ConsumableCategoryDto.fromJson(Map<String, dynamic> json) =>
      ConsumableCategoryDto(
        categoryId: json['category_id'] as int? ?? 0,
        companyId: json['company_id'] as int? ?? 0,
        name: json['name'] as String? ?? '',
        description: json['description'] as String?,
        ledgerAccountId: json['ledger_account_id'] as int?,
        ledgerCode: json['ledger_code'] as String?,
        ledgerName: json['ledger_name'] as String?,
        isActive: json['is_active'] as bool? ?? true,
      );
}

class AssetRegisterEntryDto {
  final int assetEntryId;
  final int companyId;
  final int locationId;
  final String assetTag;
  final int? productId;
  final int? barcodeId;
  final int? categoryId;
  final int? supplierId;
  final String itemName;
  final String sourceMode;
  final double quantity;
  final double unitCost;
  final double totalValue;
  final DateTime? acquisitionDate;
  final DateTime? inServiceDate;
  final String status;
  final int? offsetAccountId;
  final String? offsetAccountCode;
  final String? offsetAccountName;
  final String? notes;
  final List<String> serialNumbers;
  final List<InventoryBatchAllocationDto> batchAllocations;
  final String? categoryName;
  final String? productName;
  final String? supplierName;
  final int createdBy;
  final DateTime? createdAt;

  const AssetRegisterEntryDto({
    required this.assetEntryId,
    required this.companyId,
    required this.locationId,
    required this.assetTag,
    this.productId,
    this.barcodeId,
    this.categoryId,
    this.supplierId,
    required this.itemName,
    required this.sourceMode,
    required this.quantity,
    required this.unitCost,
    required this.totalValue,
    this.acquisitionDate,
    this.inServiceDate,
    required this.status,
    this.offsetAccountId,
    this.offsetAccountCode,
    this.offsetAccountName,
    this.notes,
    this.serialNumbers = const [],
    this.batchAllocations = const [],
    this.categoryName,
    this.productName,
    this.supplierName,
    required this.createdBy,
    this.createdAt,
  });

  String get sourceModeLabel =>
      sourceMode == 'STOCK' ? 'Stock Issue' : 'Direct Entry';

  String get statusLabel {
    final raw = status.trim();
    if (raw.isEmpty) return 'Unknown';
    return raw
        .split('_')
        .map((part) => part.isEmpty
            ? part
            : part[0].toUpperCase() + part.substring(1).toLowerCase())
        .join(' ');
  }

  String get offsetLedgerDisplay {
    final code = (offsetAccountCode ?? '').trim();
    final name = (offsetAccountName ?? '').trim();
    if (code.isEmpty && name.isEmpty) return 'Not assigned';
    if (code.isEmpty) return name;
    if (name.isEmpty) return code;
    return '$code $name';
  }

  factory AssetRegisterEntryDto.fromJson(Map<String, dynamic> json) =>
      AssetRegisterEntryDto(
        assetEntryId: json['asset_entry_id'] as int? ?? 0,
        companyId: json['company_id'] as int? ?? 0,
        locationId: json['location_id'] as int? ?? 0,
        assetTag: json['asset_tag'] as String? ?? '',
        productId: json['product_id'] as int?,
        barcodeId: json['barcode_id'] as int?,
        categoryId: json['category_id'] as int?,
        supplierId: json['supplier_id'] as int?,
        itemName: json['item_name'] as String? ?? '',
        sourceMode: json['source_mode'] as String? ?? 'DIRECT',
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
        unitCost: (json['unit_cost'] as num?)?.toDouble() ?? 0,
        totalValue: (json['total_value'] as num?)?.toDouble() ?? 0,
        acquisitionDate: json['acquisition_date'] != null
            ? DateTime.tryParse(json['acquisition_date'] as String)
            : null,
        inServiceDate: json['in_service_date'] != null
            ? DateTime.tryParse(json['in_service_date'] as String)
            : null,
        status: json['status'] as String? ?? 'ACTIVE',
        offsetAccountId: json['offset_account_id'] as int?,
        offsetAccountCode: json['offset_account_code'] as String?,
        offsetAccountName: json['offset_account_name'] as String?,
        notes: json['notes'] as String?,
        serialNumbers: (json['serial_numbers'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        batchAllocations: (json['batch_allocations'] as List?)
                ?.map((e) => InventoryBatchAllocationDto.fromJson(
                    e as Map<String, dynamic>))
                .toList() ??
            const [],
        categoryName: json['category_name'] as String?,
        productName: json['product_name'] as String?,
        supplierName: json['supplier_name'] as String?,
        createdBy: json['created_by'] as int? ?? 0,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
      );
}

class AssetRegisterSummaryDto {
  final int totalItems;
  final int activeItems;
  final double totalValue;
  final double averageItemCost;

  const AssetRegisterSummaryDto({
    required this.totalItems,
    required this.activeItems,
    required this.totalValue,
    required this.averageItemCost,
  });

  factory AssetRegisterSummaryDto.fromJson(Map<String, dynamic> json) =>
      AssetRegisterSummaryDto(
        totalItems: json['total_items'] as int? ?? 0,
        activeItems: json['active_items'] as int? ?? 0,
        totalValue: (json['total_value'] as num?)?.toDouble() ?? 0,
        averageItemCost: (json['average_item_cost'] as num?)?.toDouble() ?? 0,
      );
}

class CreateAssetRegisterEntryPayload {
  final int? categoryId;
  final int? productId;
  final int? barcodeId;
  final int? supplierId;
  final String? itemName;
  final String? assetTag;
  final String sourceMode;
  final double quantity;
  final double? unitCost;
  final DateTime acquisitionDate;
  final DateTime? inServiceDate;
  final String? status;
  final int? offsetAccountId;
  final String? notes;
  final List<String> serialNumbers;
  final List<InventoryBatchAllocationDto> batchAllocations;

  const CreateAssetRegisterEntryPayload({
    this.categoryId,
    this.productId,
    this.barcodeId,
    this.supplierId,
    this.itemName,
    this.assetTag,
    required this.sourceMode,
    required this.quantity,
    this.unitCost,
    required this.acquisitionDate,
    this.inServiceDate,
    this.status,
    this.offsetAccountId,
    this.notes,
    this.serialNumbers = const [],
    this.batchAllocations = const [],
  });

  Map<String, dynamic> toJson() => {
        if (categoryId != null) 'category_id': categoryId,
        if (productId != null) 'product_id': productId,
        if (barcodeId != null) 'barcode_id': barcodeId,
        if (supplierId != null) 'supplier_id': supplierId,
        if (itemName != null && itemName!.trim().isNotEmpty)
          'item_name': itemName!.trim(),
        if (assetTag != null && assetTag!.trim().isNotEmpty)
          'asset_tag': assetTag!.trim(),
        'source_mode': sourceMode,
        'quantity': quantity,
        if (unitCost != null) 'unit_cost': unitCost,
        'acquisition_date': acquisitionDate.toIso8601String(),
        if (inServiceDate != null)
          'in_service_date': inServiceDate!.toIso8601String(),
        if (status != null && status!.trim().isNotEmpty) 'status': status,
        if (offsetAccountId != null) 'offset_account_id': offsetAccountId,
        if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
        if (serialNumbers.isNotEmpty) 'serial_numbers': serialNumbers,
        if (batchAllocations.isNotEmpty)
          'batch_allocations': batchAllocations.map((e) => e.toJson()).toList(),
      };
}

class ConsumableEntryDto {
  final int consumptionId;
  final int companyId;
  final int locationId;
  final String entryNumber;
  final int? categoryId;
  final int? productId;
  final int? barcodeId;
  final int? supplierId;
  final String itemName;
  final String sourceMode;
  final double quantity;
  final double unitCost;
  final double totalCost;
  final DateTime? consumedAt;
  final int? offsetAccountId;
  final String? offsetAccountCode;
  final String? offsetAccountName;
  final String? notes;
  final List<String> serialNumbers;
  final List<InventoryBatchAllocationDto> batchAllocations;
  final String? categoryName;
  final String? productName;
  final String? supplierName;
  final int createdBy;
  final DateTime? createdAt;

  const ConsumableEntryDto({
    required this.consumptionId,
    required this.companyId,
    required this.locationId,
    required this.entryNumber,
    this.categoryId,
    this.productId,
    this.barcodeId,
    this.supplierId,
    required this.itemName,
    required this.sourceMode,
    required this.quantity,
    required this.unitCost,
    required this.totalCost,
    this.consumedAt,
    this.offsetAccountId,
    this.offsetAccountCode,
    this.offsetAccountName,
    this.notes,
    this.serialNumbers = const [],
    this.batchAllocations = const [],
    this.categoryName,
    this.productName,
    this.supplierName,
    required this.createdBy,
    this.createdAt,
  });

  String get sourceModeLabel =>
      sourceMode == 'STOCK' ? 'Stock Issue' : 'Direct Entry';

  String get offsetLedgerDisplay {
    final code = (offsetAccountCode ?? '').trim();
    final name = (offsetAccountName ?? '').trim();
    if (code.isEmpty && name.isEmpty) return 'Not assigned';
    if (code.isEmpty) return name;
    if (name.isEmpty) return code;
    return '$code $name';
  }

  factory ConsumableEntryDto.fromJson(Map<String, dynamic> json) =>
      ConsumableEntryDto(
        consumptionId: json['consumption_id'] as int? ?? 0,
        companyId: json['company_id'] as int? ?? 0,
        locationId: json['location_id'] as int? ?? 0,
        entryNumber: json['entry_number'] as String? ?? '',
        categoryId: json['category_id'] as int?,
        productId: json['product_id'] as int?,
        barcodeId: json['barcode_id'] as int?,
        supplierId: json['supplier_id'] as int?,
        itemName: json['item_name'] as String? ?? '',
        sourceMode: json['source_mode'] as String? ?? 'DIRECT',
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
        unitCost: (json['unit_cost'] as num?)?.toDouble() ?? 0,
        totalCost: (json['total_cost'] as num?)?.toDouble() ?? 0,
        consumedAt: json['consumed_at'] != null
            ? DateTime.tryParse(json['consumed_at'] as String)
            : null,
        offsetAccountId: json['offset_account_id'] as int?,
        offsetAccountCode: json['offset_account_code'] as String?,
        offsetAccountName: json['offset_account_name'] as String?,
        notes: json['notes'] as String?,
        serialNumbers: (json['serial_numbers'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        batchAllocations: (json['batch_allocations'] as List?)
                ?.map((e) => InventoryBatchAllocationDto.fromJson(
                    e as Map<String, dynamic>))
                .toList() ??
            const [],
        categoryName: json['category_name'] as String?,
        productName: json['product_name'] as String?,
        supplierName: json['supplier_name'] as String?,
        createdBy: json['created_by'] as int? ?? 0,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
      );
}

class ConsumableSummaryDto {
  final int totalEntries;
  final double totalQuantity;
  final double totalCost;
  final double averageUnitCost;

  const ConsumableSummaryDto({
    required this.totalEntries,
    required this.totalQuantity,
    required this.totalCost,
    required this.averageUnitCost,
  });

  factory ConsumableSummaryDto.fromJson(Map<String, dynamic> json) =>
      ConsumableSummaryDto(
        totalEntries: json['total_entries'] as int? ?? 0,
        totalQuantity: (json['total_quantity'] as num?)?.toDouble() ?? 0,
        totalCost: (json['total_cost'] as num?)?.toDouble() ?? 0,
        averageUnitCost: (json['average_unit_cost'] as num?)?.toDouble() ?? 0,
      );
}

class CreateConsumableEntryPayload {
  final int? categoryId;
  final int? productId;
  final int? barcodeId;
  final int? supplierId;
  final String? itemName;
  final String sourceMode;
  final double quantity;
  final double? unitCost;
  final DateTime consumedAt;
  final int? offsetAccountId;
  final String? notes;
  final List<String> serialNumbers;
  final List<InventoryBatchAllocationDto> batchAllocations;

  const CreateConsumableEntryPayload({
    this.categoryId,
    this.productId,
    this.barcodeId,
    this.supplierId,
    this.itemName,
    required this.sourceMode,
    required this.quantity,
    this.unitCost,
    required this.consumedAt,
    this.offsetAccountId,
    this.notes,
    this.serialNumbers = const [],
    this.batchAllocations = const [],
  });

  Map<String, dynamic> toJson() => {
        if (categoryId != null) 'category_id': categoryId,
        if (productId != null) 'product_id': productId,
        if (barcodeId != null) 'barcode_id': barcodeId,
        if (supplierId != null) 'supplier_id': supplierId,
        if (itemName != null && itemName!.trim().isNotEmpty)
          'item_name': itemName!.trim(),
        'source_mode': sourceMode,
        'quantity': quantity,
        if (unitCost != null) 'unit_cost': unitCost,
        'consumed_at': consumedAt.toIso8601String(),
        if (offsetAccountId != null) 'offset_account_id': offsetAccountId,
        if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
        if (serialNumbers.isNotEmpty) 'serial_numbers': serialNumbers,
        if (batchAllocations.isNotEmpty)
          'batch_allocations': batchAllocations.map((e) => e.toJson()).toList(),
      };
}

// Stock Transfer models
class StockTransferItemSummaryDto {
  final int productId;
  final String productName;
  final double quantity;

  StockTransferItemSummaryDto(
      {required this.productId,
      required this.productName,
      required this.quantity});

  factory StockTransferItemSummaryDto.fromJson(Map<String, dynamic> json) =>
      StockTransferItemSummaryDto(
        productId: json['product_id'] as int,
        productName: json['product_name'] as String? ?? '',
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      );
}

class StockTransferListItemDto {
  final int transferId;
  final String transferNumber;
  final int fromLocationId;
  final int toLocationId;
  final String fromLocationName;
  final String toLocationName;
  final DateTime transferDate;
  final String status; // PENDING, IN_TRANSIT, COMPLETED, CANCELLED
  final String? notes;
  final int createdBy;
  final int? approvedBy;
  final DateTime? approvedAt;
  final List<StockTransferItemSummaryDto>? items;

  StockTransferListItemDto({
    required this.transferId,
    required this.transferNumber,
    required this.fromLocationId,
    required this.toLocationId,
    required this.fromLocationName,
    required this.toLocationName,
    required this.transferDate,
    required this.status,
    this.notes,
    required this.createdBy,
    this.approvedBy,
    this.approvedAt,
    this.items,
  });

  factory StockTransferListItemDto.fromJson(Map<String, dynamic> json) =>
      StockTransferListItemDto(
        transferId: json['transfer_id'] as int,
        transferNumber: json['transfer_number'] as String? ?? '',
        fromLocationId: json['from_location_id'] as int,
        toLocationId: json['to_location_id'] as int,
        fromLocationName: json['from_location_name'] as String? ?? '',
        toLocationName: json['to_location_name'] as String? ?? '',
        transferDate:
            DateTime.tryParse(json['transfer_date'] as String? ?? '') ??
                DateTime.now(),
        status: json['status'] as String? ?? 'PENDING',
        notes: json['notes'] as String?,
        createdBy: json['created_by'] as int? ?? 0,
        approvedBy: json['approved_by'] as int?,
        approvedAt: json['approved_at'] != null
            ? DateTime.tryParse(json['approved_at'] as String)
            : null,
        items: (json['items'] as List?)
            ?.map((e) =>
                StockTransferItemSummaryDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class StockTransferDetailItemDto {
  final int transferDetailId;
  final int productId;
  final int? barcodeId;
  final double quantity;
  final double receivedQuantity;
  final String productName;
  final String? productSku;
  final String? unitSymbol;
  final String? barcode;
  final String? variantName;
  final String trackingType;
  final List<String> serialNumbers;
  final List<InventoryBatchAllocationDto> batchAllocations;

  StockTransferDetailItemDto({
    required this.transferDetailId,
    required this.productId,
    this.barcodeId,
    required this.quantity,
    required this.receivedQuantity,
    required this.productName,
    this.productSku,
    this.unitSymbol,
    this.barcode,
    this.variantName,
    this.trackingType = 'VARIANT',
    this.serialNumbers = const [],
    this.batchAllocations = const [],
  });

  factory StockTransferDetailItemDto.fromJson(Map<String, dynamic> json) =>
      StockTransferDetailItemDto(
        transferDetailId: json['transfer_detail_id'] as int? ?? 0,
        productId: json['product_id'] as int? ?? 0,
        barcodeId: json['barcode_id'] as int?,
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
        receivedQuantity: (json['received_quantity'] as num?)?.toDouble() ?? 0,
        productName: json['product_name'] as String? ?? '',
        productSku: json['product_sku'] as String?,
        unitSymbol: json['unit_symbol'] as String?,
        barcode: json['barcode'] as String?,
        variantName: json['variant_name'] as String?,
        trackingType: json['tracking_type'] as String? ?? 'VARIANT',
        serialNumbers: (json['serial_numbers'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        batchAllocations: (json['batch_allocations'] as List?)
                ?.map((e) => InventoryBatchAllocationDto.fromJson(
                    e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

class StockTransferDetailDto {
  final int transferId;
  final String transferNumber;
  final int fromLocationId;
  final int toLocationId;
  final String fromLocationName;
  final String toLocationName;
  final DateTime transferDate;
  final String status;
  final String? notes;
  final String createdByName;
  final String? approvedByName;
  final List<StockTransferDetailItemDto> items;

  StockTransferDetailDto({
    required this.transferId,
    required this.transferNumber,
    required this.fromLocationId,
    required this.toLocationId,
    required this.fromLocationName,
    required this.toLocationName,
    required this.transferDate,
    required this.status,
    this.notes,
    required this.createdByName,
    this.approvedByName,
    required this.items,
  });

  factory StockTransferDetailDto.fromJson(Map<String, dynamic> json) =>
      StockTransferDetailDto(
        transferId: json['transfer_id'] as int,
        transferNumber: json['transfer_number'] as String? ?? '',
        fromLocationId: json['from_location_id'] as int,
        toLocationId: json['to_location_id'] as int,
        fromLocationName: json['from_location_name'] as String? ?? '',
        toLocationName: json['to_location_name'] as String? ?? '',
        transferDate:
            DateTime.tryParse(json['transfer_date'] as String? ?? '') ??
                DateTime.now(),
        status: json['status'] as String? ?? 'PENDING',
        notes: json['notes'] as String?,
        createdByName: json['created_by_name'] as String? ?? '',
        approvedByName: json['approved_by_name'] as String?,
        items: (json['items'] as List?)
                ?.map((e) => StockTransferDetailItemDto.fromJson(
                    e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
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

class InventoryVariantStockDto {
  final int barcodeId;
  final String? barcode;
  final String? variantName;
  final Map<String, dynamic> variantAttributes;
  final double quantity;
  final double averageCost;
  final double? sellingPrice;
  final String trackingType;
  final bool isSerialized;

  const InventoryVariantStockDto({
    required this.barcodeId,
    this.barcode,
    this.variantName,
    this.variantAttributes = const {},
    required this.quantity,
    required this.averageCost,
    this.sellingPrice,
    this.trackingType = 'VARIANT',
    this.isSerialized = false,
  });

  String get displayName {
    final name = (variantName ?? '').trim();
    if (name.isNotEmpty) return name;
    final code = (barcode ?? '').trim();
    return code.isNotEmpty ? code : 'Default variation';
  }

  factory InventoryVariantStockDto.fromJson(Map<String, dynamic> json) =>
      InventoryVariantStockDto(
        barcodeId: json['barcode_id'] as int? ?? 0,
        barcode: json['barcode'] as String?,
        variantName: json['variant_name'] as String?,
        variantAttributes:
            (json['variant_attributes'] as Map?)?.cast<String, dynamic>() ??
                const {},
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
        averageCost: (json['average_cost'] as num?)?.toDouble() ?? 0,
        sellingPrice: (json['selling_price'] as num?)?.toDouble(),
        trackingType: json['tracking_type'] as String? ?? 'VARIANT',
        isSerialized: json['is_serialized'] as bool? ?? false,
      );
}

class InventoryBatchAllocationDto {
  final int lotId;
  final double quantity;

  const InventoryBatchAllocationDto({
    required this.lotId,
    required this.quantity,
  });

  factory InventoryBatchAllocationDto.fromJson(Map<String, dynamic> json) =>
      InventoryBatchAllocationDto(
        lotId: json['lot_id'] as int? ?? 0,
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'lot_id': lotId,
        'quantity': quantity,
      };
}

class InventoryBatchStockDto {
  final int lotId;
  final int barcodeId;
  final String? barcode;
  final String? variantName;
  final String? batchNumber;
  final DateTime? expiryDate;
  final DateTime? receivedDate;
  final double remainingQuantity;
  final double costPrice;

  const InventoryBatchStockDto({
    required this.lotId,
    required this.barcodeId,
    this.barcode,
    this.variantName,
    this.batchNumber,
    this.expiryDate,
    this.receivedDate,
    required this.remainingQuantity,
    required this.costPrice,
  });

  factory InventoryBatchStockDto.fromJson(Map<String, dynamic> json) =>
      InventoryBatchStockDto(
        lotId: json['lot_id'] as int? ?? 0,
        barcodeId: json['barcode_id'] as int? ?? 0,
        barcode: json['barcode'] as String?,
        variantName: json['variant_name'] as String?,
        batchNumber: json['batch_number'] as String?,
        expiryDate: json['expiry_date'] != null
            ? DateTime.tryParse(json['expiry_date'] as String)
            : null,
        receivedDate: json['received_date'] != null
            ? DateTime.tryParse(json['received_date'] as String)
            : null,
        remainingQuantity:
            (json['remaining_quantity'] as num?)?.toDouble() ?? 0,
        costPrice: (json['cost_price'] as num?)?.toDouble() ?? 0,
      );
}

class InventorySerialStockDto {
  final int productSerialId;
  final int barcodeId;
  final String serialNumber;
  final double costPrice;
  final String? barcode;
  final String? variantName;
  final String trackingType;
  final String? batchNumber;
  final DateTime? expiryDate;

  const InventorySerialStockDto({
    required this.productSerialId,
    required this.barcodeId,
    required this.serialNumber,
    required this.costPrice,
    this.barcode,
    this.variantName,
    this.trackingType = 'SERIAL',
    this.batchNumber,
    this.expiryDate,
  });

  factory InventorySerialStockDto.fromJson(Map<String, dynamic> json) =>
      InventorySerialStockDto(
        productSerialId: json['product_serial_id'] as int? ?? 0,
        barcodeId: json['barcode_id'] as int? ?? 0,
        serialNumber: json['serial_number'] as String? ?? '',
        costPrice: (json['cost_price'] as num?)?.toDouble() ?? 0,
        barcode: json['barcode'] as String?,
        variantName: json['variant_name'] as String?,
        trackingType: json['tracking_type'] as String? ?? 'SERIAL',
        batchNumber: json['batch_number'] as String?,
        expiryDate: json['expiry_date'] != null
            ? DateTime.tryParse(json['expiry_date'] as String)
            : null,
      );
}

class InventoryTrackingSelection {
  final int? barcodeId;
  final String trackingType;
  final bool isSerialized;
  final String? barcode;
  final String? variantName;
  final List<String> serialNumbers;
  final List<InventoryBatchAllocationDto> batchAllocations;
  final String? batchNumber;
  final DateTime? expiryDate;
  final List<String> serialBatchLabels;

  const InventoryTrackingSelection({
    this.barcodeId,
    this.trackingType = 'VARIANT',
    this.isSerialized = false,
    this.barcode,
    this.variantName,
    this.serialNumbers = const [],
    this.batchAllocations = const [],
    this.batchNumber,
    this.expiryDate,
    this.serialBatchLabels = const [],
  });

  String summary(double quantity) {
    final parts = <String>[];
    if ((variantName ?? '').trim().isNotEmpty) {
      parts.add(variantName!.trim());
    } else if ((barcode ?? '').trim().isNotEmpty) {
      parts.add(barcode!.trim());
    }
    if (isSerialized) {
      parts.add(
          '${serialNumbers.length}/${quantity.toStringAsFixed(0)} serials');
      if (serialBatchLabels.isNotEmpty) {
        parts.add(serialBatchLabels.join(', '));
      }
    }
    if (trackingType == 'BATCH') {
      if ((batchNumber ?? '').trim().isNotEmpty) {
        parts.add('Batch ${batchNumber!.trim()}');
      } else if (batchAllocations.isNotEmpty) {
        parts.add('${batchAllocations.length} batch(es)');
      }
    }
    return parts.isEmpty ? 'Tracking configured' : parts.join(' • ');
  }

  Map<String, dynamic> toIssueJson() => {
        if (barcodeId != null && barcodeId! > 0) 'barcode_id': barcodeId,
        if (serialNumbers.isNotEmpty) 'serial_numbers': serialNumbers,
        if (batchAllocations.isNotEmpty)
          'batch_allocations': batchAllocations.map((e) => e.toJson()).toList(),
      };

  Map<String, dynamic> toReceiveJson() => {
        if (barcodeId != null && barcodeId! > 0) 'barcode_id': barcodeId,
        if (serialNumbers.isNotEmpty) 'serial_numbers': serialNumbers,
        if ((batchNumber ?? '').trim().isNotEmpty) 'batch_number': batchNumber,
        if (expiryDate != null) 'expiry_date': expiryDate!.toIso8601String(),
      };
}
