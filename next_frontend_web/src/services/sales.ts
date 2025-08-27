import api, { accessToken } from './apiClient';
import { Sale, Quote } from '../types';

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

// Invoice CRUD
export const getInvoice = (id: string) => api.get<Sale>(`/api/v1/sales/${id}`);
export const updateInvoice = (id: string, payload: Partial<Sale>) =>
  api.put<Sale>(`/api/v1/sales/${id}`, payload);
export const deleteInvoice = (id: string) =>
  api.delete<void>(`/api/v1/sales/${id}`);

// Quote CRUD
export const getQuotes = () => api.get<Quote[]>('/api/v1/sales/quotes');
export const getQuote = (id: string) =>
  api.get<Quote>(`/api/v1/sales/quotes/${id}`);
export const createQuote = (payload: Partial<Quote>) =>
  api.post<Quote>('/api/v1/sales/quotes', payload);
export const updateQuote = (id: string, payload: Partial<Quote>) =>
  api.put<Quote>(`/api/v1/sales/quotes/${id}`, payload);
export const deleteQuote = (id: string) =>
  api.delete<void>(`/api/v1/sales/quotes/${id}`);

export const printQuote = (id: string, payload: Record<string, any> = {}) =>
  api.post<void>(`/api/v1/sales/quotes/${id}/print`, payload);

export const shareQuote = (id: string, payload: Record<string, any> = {}) =>
  api.post<void>(`/api/v1/sales/quotes/${id}/share`, payload);

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
