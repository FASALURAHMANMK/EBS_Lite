export interface PurchaseOrderItemPayload {
  productId: number;
  quantity: number;
  unitPrice: number;
}

export interface PurchaseOrderPayload {
  supplierId: number | string;
  referenceNumber?: string;
  items: PurchaseOrderItemPayload[];
}

export interface PurchaseOrder {
  purchaseOrderId: number;
  supplierId: number;
  referenceNumber?: string;
  status: string;
  totalAmount: number;
  items: PurchaseOrderItemPayload[];
}

export interface GoodsReceiptItemPayload {
  productId: number;
  quantity: number;
}

export interface GoodsReceiptPayload {
  purchaseId: number | string;
  items: GoodsReceiptItemPayload[];
}

export interface GoodsReceipt {
  goodsReceiptId: number;
  purchaseId: number;
  items: GoodsReceiptItemPayload[];
}

export interface PurchaseReturnItemPayload {
  productId: number;
  quantity: number;
  unitPrice: number;
}

export interface PurchaseReturnPayload {
  purchaseId: number | string;
  reason?: string;
  items: PurchaseReturnItemPayload[];
}

export interface PurchaseReturn {
  returnId: number;
  purchaseId: number;
  reason?: string;
  items: PurchaseReturnItemPayload[];
}
