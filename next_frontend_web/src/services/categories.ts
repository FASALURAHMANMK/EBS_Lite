import api from './apiClient';
import { Category } from '../types';

export const getCategories = () => api.get<Category[]>('/api/v1/categories');
export const createCategory = (payload: Partial<Category>) =>
  api.post<Category>('/api/v1/categories', payload);
export const updateCategory = (id: string, payload: Partial<Category>) =>
  api.put<Category>(`/api/v1/categories/${id}`, payload);
export const deleteCategory = (id: string) => api.delete<void>(`/api/v1/categories/${id}`);
