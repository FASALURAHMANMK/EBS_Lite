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

