import api from './apiClient';

export const getMetrics = <T = any>() => api.get<T>('/api/v1/dashboard/metrics');
export const getQuickActions = <T = any>() => api.get<T>('/api/v1/dashboard/quick-actions');
