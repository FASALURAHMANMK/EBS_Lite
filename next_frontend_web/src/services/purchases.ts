import api from './apiClient';
import {
  PurchaseOrderPayload,
  PurchaseOrder,
  GoodsReceiptPayload,
  GoodsReceipt,
  PurchaseReturnPayload,
  PurchaseReturn,
  Purchase,
} from '../types/purchases';

export const getPurchases = (query = '') =>
  api.get<Purchase[]>(`/api/v1/purchases${query}`);

export const getPurchaseHistory = () =>
  api.get<any>('/api/v1/purchases/history');

export const getPendingPurchases = () =>
  api.get<Purchase[]>(`/api/v1/purchases/pending`);

export const getPurchase = (id: string) =>
  api.get<Purchase>(`/api/v1/purchases/${id}`);

export const createPurchase = (payload: any) =>
  api.post<Purchase>('/api/v1/purchases', payload);

export const createQuickPurchase = (payload: any) =>
  api.post<Purchase>('/api/v1/purchases/quick', payload);

export const updatePurchase = (id: string, payload: any) =>
  api.put<Purchase>(`/api/v1/purchases/${id}`, payload);

export const receivePurchase = (id: string, payload: any) =>
  api.put<Purchase>(`/api/v1/purchases/${id}/receive`, payload);

export const deletePurchase = (id: string) =>
  api.delete<void>(`/api/v1/purchases/${id}`);

export const createPurchaseOrder = (payload: PurchaseOrderPayload) =>
  api.post<PurchaseOrder>('/api/v1/purchase-orders', payload);

export const updatePurchaseOrder = (
  id: string,
  payload: Partial<PurchaseOrder>
) => api.put<PurchaseOrder>(`/api/v1/purchase-orders/${id}`, payload);

export const deletePurchaseOrder = (id: string) =>
  api.delete<void>(`/api/v1/purchase-orders/${id}`);

export const approvePurchaseOrder = (id: string) =>
  api.put<PurchaseOrder>(`/api/v1/purchase-orders/${id}/approve`);

export const recordGoodsReceipt = (payload: GoodsReceiptPayload) =>
  api.post<GoodsReceipt | null>('/api/v1/goods-receipts', payload);

export const createPurchaseReturn = (payload: PurchaseReturnPayload) => {
  // payload items should include purchaseDetailId
  return api.post<PurchaseReturn>('/api/v1/purchase-returns', payload);
};

export const getPurchaseReturns = () =>
  api.get<PurchaseReturn[]>('/api/v1/purchase-returns');

export const getPurchaseReturn = (id: string) =>
  api.get<PurchaseReturn>(`/api/v1/purchase-returns/${id}`);

export const updatePurchaseReturn = (
  id: string,
  payload: PurchaseReturnPayload
) => api.put<PurchaseReturn>(`/api/v1/purchase-returns/${id}`, payload);

export const deletePurchaseReturn = (id: string) =>
  api.delete<void>(`/api/v1/purchase-returns/${id}`);
