import api from './apiClient';
import { Location } from '../types';

export const getLocations = () => api.get<Location[]>('/api/v1/locations');

export const createLocation = (payload: Partial<Location>) =>
  api.post<Location>('/api/v1/locations', payload);

export const updateLocation = (id: string, payload: Partial<Location>) =>
  api.put<void>(`/api/v1/locations/${id}`, payload);

export const deleteLocation = (id: string) =>
  api.delete<void>(`/api/v1/locations/${id}`);
