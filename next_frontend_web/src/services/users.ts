import api from './apiClient';
import { User } from '../types';

export const getUsers = () => api.get<User[]>('/api/v1/users');

export const createUser = (payload: Partial<User>) =>
  api.post<{ userId: string }>('/api/v1/users', payload);

export const updateUser = (id: string, payload: Partial<User>) =>
  api.put<void>(`/api/v1/users/${id}`, payload);

export const deleteUser = (id: string) =>
  api.delete<void>(`/api/v1/users/${id}`);
