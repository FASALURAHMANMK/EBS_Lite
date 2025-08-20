import api from './apiClient';

export const createPurchaseOrder = (payload: any) =>
  api.post('/api/v1/purchase-orders', payload);
export const recordGoodsReceipt = (payload: any) =>
  api.post('/api/v1/goods-receipts', payload);
export const createPurchaseReturn = (payload: any) =>
  api.post('/api/v1/purchase-returns', payload);
