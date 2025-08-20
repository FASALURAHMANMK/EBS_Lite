import api from './apiClient';
import { Company } from '../types';

export const createCompany = (payload: Partial<Company>) =>
  api.post<Company>('/api/v1/companies', payload);
