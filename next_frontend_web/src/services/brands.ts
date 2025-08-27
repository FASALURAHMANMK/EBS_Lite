import api from './apiClient';
import { Brand } from '../types';

export const getBrands = () => api.get<Brand[]>('/api/v1/brands');

export const createBrand = (payload: Partial<Brand>) =>
  api.post<Brand>('/api/v1/brands', payload);
