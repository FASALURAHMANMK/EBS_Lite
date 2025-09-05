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
      receivedDate: DateTime.tryParse((json['received_date'] ?? '').toString()) ?? DateTime.now(),
      receivedBy: json['received_by'] as int? ?? 0,
      supplierName: (json['supplier'] is Map && (json['supplier']['name'] ?? '') != null)
          ? (json['supplier']['name'] as String)
          : (json['supplier_name'] as String?)
    );
  }
}

class GrnCreateItem {
  GrnCreateItem({required this.productId, required this.quantity, required this.unitPrice, this.taxId, this.discountPercent, this.discountAmount});
  final int productId;
  final double quantity;
  final double unitPrice;
  final int? taxId;
  final double? discountPercent;
  final double? discountAmount;
}

class GoodsReceiptItemDto {
  GoodsReceiptItemDto({
    required this.goodsReceiptItemId,
    required this.productId,
    required this.receivedQuantity,
    required this.unitPrice,
    required this.lineTotal,
    this.productName,
    this.sku,
  });
  final int goodsReceiptItemId;
  final int productId;
  final double receivedQuantity;
  final double unitPrice;
  final double lineTotal;
  final String? productName;
  final String? sku;

  factory GoodsReceiptItemDto.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? prod = json['product'] as Map<String, dynamic>?;
    return GoodsReceiptItemDto(
      goodsReceiptItemId: json['goods_receipt_item_id'] as int? ?? json['receipt_item_id'] as int? ?? 0,
      productId: json['product_id'] as int,
      receivedQuantity: (json['received_quantity'] as num?)?.toDouble() ?? 0,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0,
      lineTotal: (json['line_total'] as num?)?.toDouble() ?? 0,
      productName: prod != null ? prod['name'] as String? : null,
      sku: prod != null ? prod['sku'] as String? : null,
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
