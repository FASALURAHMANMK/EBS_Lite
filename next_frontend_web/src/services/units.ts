import api from './apiClient';
import { Unit } from '../types';

export const getUnits = () => api.get<Unit[]>('/api/v1/units');

export const createUnit = (payload: Partial<Unit>) =>
  api.post<Unit>('/api/v1/units', payload);
