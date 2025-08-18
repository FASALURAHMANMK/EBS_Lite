import api from './apiClient';
import { User, Company } from '../types';

interface AuthResponse {
  token: string;
  user: User;
  company: Company;
}

export const login = async (username: string, password: string): Promise<AuthResponse> => {
  const data = await api.post<AuthResponse>('/auth/login', { username, password });
  if (typeof window !== 'undefined') {
    localStorage.setItem('token', data.token);
  }
  return data;
};

export const register = async (payload: Record<string, any>): Promise<AuthResponse> => {
  const data = await api.post<AuthResponse>('/auth/register', payload);
  if (typeof window !== 'undefined') {
    localStorage.setItem('token', data.token);
  }
  return data;
};

export const getProfile = () => api.get<User>('/auth/me');
