import api from './apiClient';
import { Sale } from '../types';

export interface SaleReturnItemPayload {
  productId: string;
  quantity: number;
}

export interface SaleReturnPayload {
  items: SaleReturnItemPayload[];
  reason?: string;
}

export const searchSale = (saleId: string) =>
  api.get<Sale>(`/api/v1/sale-returns/search/${saleId}`);

export const processReturn = (saleId: string, payload: SaleReturnPayload) =>
  api.post(`/api/v1/sale-returns/process/${saleId}`, payload);

