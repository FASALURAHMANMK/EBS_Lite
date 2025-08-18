import api from './apiClient';
import { Product } from '../types';

export const getProducts = (query = '') =>
  api.get<Product[]>(`/products${query}`);
export const getProduct = (id: string) => api.get<Product>(`/products/${id}`);
export const createProduct = (payload: Partial<Product>) =>
  api.post<Product>('/products', payload);
export const updateProduct = (id: string, payload: Partial<Product>) =>
  api.put<Product>(`/products/${id}`, payload);
export const deleteProduct = (id: string) => api.delete<void>(`/products/${id}`);
