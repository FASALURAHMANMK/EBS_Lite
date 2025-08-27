import api, { accessToken } from './apiClient';
import { Sale } from '../types';

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080';

const buildQuery = (filters: Record<string, any>) => {
  const params = new URLSearchParams();
  Object.entries(filters).forEach(([key, value]) => {
    if (value) params.append(key, String(value));
  });
  const query = params.toString();
  return query ? `?${query}` : '';
};

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

export const getSalesHistory = (filters: Record<string, any> = {}) =>
  api.get<Sale[]>(`/api/v1/sales/history${buildQuery(filters)}`);

export const exportSalesHistory = async (
  filters: Record<string, any> = {}
) => {
  const res = await fetch(
    `${API_BASE_URL}/api/v1/sales/history/export${buildQuery(filters)}`,
    {
      headers: accessToken ? { Authorization: `Bearer ${accessToken}` } : undefined,
    }
  );
  if (!res.ok) throw new Error('Failed to export sales history');
  return res.blob();
};
