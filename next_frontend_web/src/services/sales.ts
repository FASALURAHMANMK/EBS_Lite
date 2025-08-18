import api from './apiClient';
import { Sale } from '../types';

export const getSales = () => api.get<Sale[]>('/sales');
export const createSale = (payload: Partial<Sale>) => api.post<Sale>('/sales', payload);
