import api from './apiClient';
import { Customer, CreditTransaction } from '../types';

export const getCustomers = () => api.get<Customer[]>('/customers');
export const createCustomer = (payload: Partial<Customer>) => api.post<Customer>('/customers', payload);
export const updateCustomer = (id: string, payload: Partial<Customer>) => api.put<Customer>(`/customers/${id}`, payload);
export const deleteCustomer = (id: string) => api.delete<void>(`/customers/${id}`);
export const updateCustomerCredit = (id: string, amount: number, type: 'credit' | 'debit', description: string) =>
  api.post<Customer>(`/customers/${id}/credit`, { amount, type, description });
export const getCustomerCreditHistory = (id: string) =>
  api.get<CreditTransaction[]>(`/customers/${id}/credit`);
export const searchCustomers = (query: string) =>
  api.get<Customer[]>(`/customers?search=${encodeURIComponent(query)}`);
