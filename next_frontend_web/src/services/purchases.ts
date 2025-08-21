import api from './apiClient';
import {
  PurchaseOrderPayload,
  PurchaseOrder,
  GoodsReceiptPayload,
  GoodsReceipt,
  PurchaseReturnPayload,
  PurchaseReturn,
} from '../types/purchases';

export const createPurchaseOrder = (payload: PurchaseOrderPayload) =>
  api.post<PurchaseOrder>('/api/v1/purchase-orders', payload);

export const recordGoodsReceipt = (payload: GoodsReceiptPayload) =>
  api.post<GoodsReceipt>('/api/v1/goods-receipts', payload);

export const createPurchaseReturn = (payload: PurchaseReturnPayload) =>
  api.post<PurchaseReturn>('/api/v1/purchase-returns', payload);
