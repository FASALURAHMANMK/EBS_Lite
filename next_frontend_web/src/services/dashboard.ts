import api from './apiClient';

export const getStats = () => api.get('/api/v1/dashboard');
