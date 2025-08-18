import api from './apiClient';
import { Category } from '../types';

export const getCategories = () => api.get<Category[]>('/categories');
export const createCategory = (payload: Partial<Category>) => api.post<Category>('/categories', payload);
export const updateCategory = (id: string, payload: Partial<Category>) => api.put<Category>(`/categories/${id}`, payload);
export const deleteCategory = (id: string) => api.delete<void>(`/categories/${id}`);
