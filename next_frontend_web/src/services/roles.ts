import api from './apiClient';
import { Role } from '../types';

export const getRoles = () => api.get<Role[]>('/api/v1/roles');

export const createRole = (payload: Partial<Role>) =>
  api.post<Role>('/api/v1/roles', payload);

export const updateRole = (id: string, payload: Partial<Role>) =>
  api.put<void>(`/api/v1/roles/${id}`, payload);

export const deleteRole = (id: string) =>
  api.delete<void>(`/api/v1/roles/${id}`);

export const getRolePermissions = (id: string) =>
  api.get<string[]>(`/api/v1/roles/${id}/permissions`);

export const assignPermissions = (id: string, permissions: string[]) =>
  api.post<void>(`/api/v1/roles/${id}/permissions`, { permissions });

export const getPermissions = () =>
  api.get<string[]>('/api/v1/permissions');
