import api from './apiClient';
import { Supplier } from '../types';

export const getSuppliers = () => api.get<Supplier[]>('/api/v1/suppliers');
export const createSupplier = (payload: Partial<Supplier>) =>
  api.post<Supplier>('/api/v1/suppliers', payload);
export const updateSupplier = (id: string, payload: Partial<Supplier>) =>
  api.put<Supplier>(`/api/v1/suppliers/${id}`, payload);
export const deleteSupplier = (id: string) =>
  api.delete<void>(`/api/v1/suppliers/${id}`);
export const searchSuppliers = (query: string) =>
  api.get<Supplier[]>(`/api/v1/suppliers?search=${encodeURIComponent(query)}`);
