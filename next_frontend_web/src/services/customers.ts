import api from './apiClient';
import { Customer, CreditTransaction } from '../types';

export const getCustomers = () => api.get<Customer[]>('/api/v1/customers');
export const createCustomer = (payload: Partial<Customer>) =>
  api.post<Customer>('/api/v1/customers', payload);
export const updateCustomer = (id: string, payload: Partial<Customer>) =>
  api.put<Customer>(`/api/v1/customers/${id}`, payload);
export const deleteCustomer = (id: string) => api.delete<void>(`/api/v1/customers/${id}`);
export const updateCustomerCredit = (
  id: string,
  amount: number,
  type: 'credit' | 'debit',
  description: string
) =>
  api.post<Customer>(`/api/v1/customers/${id}/credit`, { amount, type, description });
export const getCustomerCreditHistory = (id: string) =>
  api.get<CreditTransaction[]>(`/api/v1/customers/${id}/credit`);
export const searchCustomers = (query: string) =>
  api.get<Customer[]>(`/api/v1/customers?search=${encodeURIComponent(query)}`);
