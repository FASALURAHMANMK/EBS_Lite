import api from './apiClient';
import { ProductStockLevel } from '../types';

export const getProductStock = (productId: string) =>
  api.get<ProductStockLevel[]>(`/api/v1/inventory/stock?product_id=${productId}`);

export const adjustStock = (payload: {
  productId: string;
  adjustment: number;
  reason: string;
}) => api.post<void>('/api/v1/inventory/stock-adjustment', payload);

export const getStockAdjustments = () =>
  api.get<any[]>(`/api/v1/inventory/stock-adjustments`);

export const createTransfer = (payload: {
  toLocationId: string;
  items: Array<{ productId: string; quantity: number }>;
  notes?: string;
}) => api.post('/api/v1/inventory/transfers', payload);

export const getTransfers = () => api.get<any[]>('/api/v1/inventory/transfers');
