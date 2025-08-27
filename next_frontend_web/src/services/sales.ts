import api from './apiClient';
import { Sale } from '../types';

export const getSales = () => api.get<Sale[]>('/api/v1/sales');
export const createSale = (payload: Partial<Sale>) => api.post<Sale>('/api/v1/sales', payload);
export const createQuickSale = (payload: any) =>
  api.post('/api/v1/sales/quick', payload);
