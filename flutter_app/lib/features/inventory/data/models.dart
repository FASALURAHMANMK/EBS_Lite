import 'dart:convert';

class InventoryListItem {
  final int productId;
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

  const InventoryListItem({
    required this.productId,
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
      );

  factory InventoryListItem.fromPOSJson(Map<String, dynamic> json) =>
      InventoryListItem(
        productId: json['product_id'] as int,
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

  const InventoryVariantStockDto({
    required this.barcodeId,
    this.barcode,
    this.variantName,
    this.variantAttributes = const {},
    required this.quantity,
    required this.averageCost,
    this.sellingPrice,
    this.trackingType = 'VARIANT',
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

  const InventorySerialStockDto({
    required this.productSerialId,
    required this.barcodeId,
    required this.serialNumber,
    required this.costPrice,
    this.barcode,
    this.variantName,
    this.trackingType = 'SERIAL',
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
      );
}

class InventoryTrackingSelection {
  final int? barcodeId;
  final String trackingType;
  final String? barcode;
  final String? variantName;
  final List<String> serialNumbers;
  final List<InventoryBatchAllocationDto> batchAllocations;
  final String? batchNumber;
  final DateTime? expiryDate;

  const InventoryTrackingSelection({
    this.barcodeId,
    this.trackingType = 'VARIANT',
    this.barcode,
    this.variantName,
    this.serialNumbers = const [],
    this.batchAllocations = const [],
    this.batchNumber,
    this.expiryDate,
  });

  String summary(double quantity) {
    final parts = <String>[];
    if ((variantName ?? '').trim().isNotEmpty) {
      parts.add(variantName!.trim());
    } else if ((barcode ?? '').trim().isNotEmpty) {
      parts.add(barcode!.trim());
    }
    if (trackingType == 'SERIAL') {
      parts.add(
          '${serialNumbers.length}/${quantity.toStringAsFixed(0)} serials');
    } else if (trackingType == 'BATCH') {
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
