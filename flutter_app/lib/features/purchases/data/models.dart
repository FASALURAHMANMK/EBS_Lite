class GoodsReceiptDto {
  GoodsReceiptDto({
    required this.goodsReceiptId,
    required this.receiptNumber,
    this.purchaseId,
    required this.locationId,
    required this.supplierId,
    required this.receivedDate,
    required this.receivedBy,
    this.supplierName,
  });

  final int goodsReceiptId;
  final String receiptNumber;
  final int? purchaseId;
  final int locationId;
  final int supplierId;
  final DateTime receivedDate;
  final int receivedBy;
  final String? supplierName;

  factory GoodsReceiptDto.fromJson(Map<String, dynamic> json) {
    return GoodsReceiptDto(
        goodsReceiptId: json['goods_receipt_id'] as int,
        receiptNumber: (json['receipt_number'] ?? '').toString(),
        purchaseId: json['purchase_id'] as int?,
        locationId: json['location_id'] as int,
        supplierId: json['supplier_id'] as int,
        receivedDate:
            DateTime.tryParse((json['received_date'] ?? '').toString()) ??
                DateTime.now(),
        receivedBy: json['received_by'] as int? ?? 0,
        supplierName: (json['supplier'] is Map &&
                (json['supplier']['name'] ?? '') != null)
            ? (json['supplier']['name'] as String)
            : (json['supplier_name'] as String?));
  }
}

class GrnCreateItem {
  GrnCreateItem(
      {required this.productId,
      required this.quantity,
      required this.unitPrice,
      this.barcodeId,
      this.serialNumbers = const [],
      this.batchNumber,
      this.expiryDate,
      this.taxId,
      this.discountPercent,
      this.discountAmount});
  final int productId;
  final double quantity;
  final double unitPrice;
  final int? barcodeId;
  final List<String> serialNumbers;
  final String? batchNumber;
  final DateTime? expiryDate;
  final int? taxId;
  final double? discountPercent;
  final double? discountAmount;
}

class CostAdjustmentDraft {
  CostAdjustmentDraft({
    required this.label,
    required this.amount,
    required this.direction,
  });

  final String label;
  final double amount;
  final String direction;

  Map<String, dynamic> toJson() => {
        'label': label,
        'amount': amount,
        'direction': direction,
      };
}

class GoodsReceiptItemDto {
  GoodsReceiptItemDto({
    required this.goodsReceiptItemId,
    required this.purchaseDetailId,
    required this.productId,
    required this.receivedQuantity,
    required this.unitPrice,
    required this.lineTotal,
    this.barcodeId,
    this.productName,
    this.sku,
  });
  final int goodsReceiptItemId;
  final int purchaseDetailId;
  final int productId;
  final double receivedQuantity;
  final double unitPrice;
  final double lineTotal;
  final int? barcodeId;
  final String? productName;
  final String? sku;

  factory GoodsReceiptItemDto.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? prod = json['product'] as Map<String, dynamic>?;
    return GoodsReceiptItemDto(
      goodsReceiptItemId: json['goods_receipt_item_id'] as int? ??
          json['receipt_item_id'] as int? ??
          0,
      purchaseDetailId: json['purchase_detail_id'] as int? ?? 0,
      productId: json['product_id'] as int,
      receivedQuantity: (json['received_quantity'] as num?)?.toDouble() ?? 0,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0,
      lineTotal: (json['line_total'] as num?)?.toDouble() ?? 0,
      barcodeId: json['barcode_id'] as int?,
      productName: prod != null ? prod['name'] as String? : null,
      sku: prod != null ? prod['sku'] as String? : null,
    );
  }
}

class PurchaseCostAdjustmentDto {
  PurchaseCostAdjustmentDto({
    required this.adjustmentId,
    required this.adjustmentNumber,
    required this.adjustmentType,
    this.goodsReceiptId,
    this.purchaseId,
    required this.locationId,
    required this.supplierId,
    required this.adjustmentDate,
    required this.totalAmount,
    this.referenceNumber,
    this.notes,
    this.supplierName,
    this.items = const [],
  });

  final int adjustmentId;
  final String adjustmentNumber;
  final String adjustmentType;
  final int? goodsReceiptId;
  final int? purchaseId;
  final int locationId;
  final int supplierId;
  final DateTime adjustmentDate;
  final double totalAmount;
  final String? referenceNumber;
  final String? notes;
  final String? supplierName;
  final List<PurchaseCostAdjustmentItemDto> items;

  bool get isSupplierDebitNote => adjustmentType == 'SUPPLIER_DEBIT_NOTE';

  factory PurchaseCostAdjustmentDto.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List? ?? const [])
        .map(
          (e) => PurchaseCostAdjustmentItemDto.fromJson(
            e as Map<String, dynamic>,
          ),
        )
        .toList();
    return PurchaseCostAdjustmentDto(
      adjustmentId: json['adjustment_id'] as int? ?? 0,
      adjustmentNumber: (json['adjustment_number'] ?? '').toString(),
      adjustmentType: (json['adjustment_type'] ?? '').toString(),
      goodsReceiptId: json['goods_receipt_id'] as int?,
      purchaseId: json['purchase_id'] as int?,
      locationId: json['location_id'] as int? ?? 0,
      supplierId: json['supplier_id'] as int? ?? 0,
      adjustmentDate:
          DateTime.tryParse((json['adjustment_date'] ?? '').toString()) ??
              DateTime.now(),
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      referenceNumber: json['reference_number'] as String?,
      notes: json['notes'] as String?,
      supplierName: (json['supplier'] is Map<String, dynamic>)
          ? (json['supplier']['name'] as String?)
          : null,
      items: items,
    );
  }
}

class PurchaseCostAdjustmentItemDto {
  PurchaseCostAdjustmentItemDto({
    required this.adjustmentItemId,
    required this.productId,
    required this.adjustmentLabel,
    required this.stockAction,
    required this.signedAmount,
    this.purchaseDetailId,
    this.goodsReceiptItemId,
    this.quantity,
    this.stockQuantity,
    this.productName,
  });

  final int adjustmentItemId;
  final int productId;
  final int? purchaseDetailId;
  final int? goodsReceiptItemId;
  final String adjustmentLabel;
  final String stockAction;
  final double signedAmount;
  final double? quantity;
  final double? stockQuantity;
  final String? productName;

  factory PurchaseCostAdjustmentItemDto.fromJson(Map<String, dynamic> json) {
    final product = json['product'] as Map<String, dynamic>?;
    return PurchaseCostAdjustmentItemDto(
      adjustmentItemId: json['adjustment_item_id'] as int? ?? 0,
      productId: json['product_id'] as int? ?? 0,
      purchaseDetailId: json['purchase_detail_id'] as int?,
      goodsReceiptItemId: json['goods_receipt_item_id'] as int?,
      adjustmentLabel: (json['adjustment_label'] ?? '').toString(),
      stockAction: (json['stock_action'] ?? '').toString(),
      signedAmount: (json['signed_amount'] as num?)?.toDouble() ?? 0,
      quantity: (json['quantity'] as num?)?.toDouble(),
      stockQuantity: (json['stock_quantity'] as num?)?.toDouble(),
      productName: product?['name'] as String?,
    );
  }
}

class GoodsReceiptDetailDto extends GoodsReceiptDto {
  GoodsReceiptDetailDto({
    required super.goodsReceiptId,
    required super.receiptNumber,
    required super.purchaseId,
    required super.locationId,
    required super.supplierId,
    required super.receivedDate,
    required super.receivedBy,
    super.supplierName,
    required this.items,
  });

  final List<GoodsReceiptItemDto> items;

  factory GoodsReceiptDetailDto.fromJson(Map<String, dynamic> json) {
    final base = GoodsReceiptDto.fromJson(json);
    final items = (json['items'] as List? ?? const [])
        .map((e) => GoodsReceiptItemDto.fromJson(e as Map<String, dynamic>))
        .toList();
    return GoodsReceiptDetailDto(
      goodsReceiptId: base.goodsReceiptId,
      receiptNumber: base.receiptNumber,
      purchaseId: base.purchaseId,
      locationId: base.locationId,
      supplierId: base.supplierId,
      receivedDate: base.receivedDate,
      receivedBy: base.receivedBy,
      supplierName: base.supplierName,
      items: items,
    );
  }
}
