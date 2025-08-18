import api from './apiClient';

export const getStats = () => api.get('/dashboard');
