import api from './apiClient';
import { Sale } from '../types';

export const getSales = () => api.get<Sale[]>('/api/v1/sales');
export const createSale = (payload: Partial<Sale>) => api.post<Sale>('/api/v1/sales', payload);
export const createQuickSale = (payload: any) =>
  api.post('/api/v1/sales/quick', payload);

export const holdSale = (id: string) =>
  api.post<Sale>(`/api/v1/sales/${id}/hold`);

export const resumeSale = (id: string) =>
  api.post<Sale>(`/api/v1/sales/${id}/resume`);

export const applyPromotion = (id: string, code: string) =>
  api.post<Sale>(`/api/v1/sales/${id}/promotion`, { code });

export const applyLoyaltyPoints = (id: string, points: number) =>
  api.post<Sale>(`/api/v1/sales/${id}/loyalty`, { points });
