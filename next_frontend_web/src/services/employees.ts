import api from './apiClient';
import { Employee } from '../types';

export const getEmployees = () => api.get<Employee[]>('/api/v1/employees');

export const createEmployee = (payload: Partial<Employee>) =>
  api.post<Employee>('/api/v1/employees', payload);

export const updateEmployee = (id: string, payload: Partial<Employee>) =>
  api.put<void>(`/api/v1/employees/${id}`, payload);

export const deleteEmployee = (id: string) =>
  api.delete<void>(`/api/v1/employees/${id}`);
