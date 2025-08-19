import api from './apiClient';
import { Product } from '../types';

export const getProducts = (query = '') =>
  api.get<Product[]>(`/api/v1/products${query}`);
export const getProduct = (id: string) => api.get<Product>(`/api/v1/products/${id}`);
export const createProduct = (payload: Partial<Product>) =>
  api.post<Product>('/api/v1/products', payload);
export const updateProduct = (id: string, payload: Partial<Product>) =>
  api.put<Product>(`/api/v1/products/${id}`, payload);
export const deleteProduct = (id: string) => api.delete<void>(`/api/v1/products/${id}`);
