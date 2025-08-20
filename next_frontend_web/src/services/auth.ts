import api, { setAuthTokens, clearAuthTokens } from './apiClient';
import { User, Company } from '../types';

interface AuthResponse {
  accessToken: string;
  refreshToken: string;
  user: User;
  company: Company;
}

export const login = async (
  username: string,
  password: string
): Promise<{ user: User; company: Company }> => {
  const data = await api.post<AuthResponse>(
    '/api/v1/auth/login',
    { username, password },
    { auth: false }
  );
  setAuthTokens({ accessToken: data.accessToken, refreshToken: data.refreshToken });
  return { user: data.user, company: data.company };
};

export const register = async (
  payload: Record<string, any>
): Promise<{ user: User; company: Company }> => {
  const data = await api.post<AuthResponse>(
    '/api/v1/auth/register',
    payload,
    { auth: false }
  );
  setAuthTokens({ accessToken: data.accessToken, refreshToken: data.refreshToken });
  return { user: data.user, company: data.company };
};

export const getProfile = () =>
  api.get<{ user: User; company: Company }>('/api/v1/auth/me');

export const logout = async () => {
  await api.post('/api/v1/auth/logout');
  clearAuthTokens();
};

export const forgotPassword = (email: string) =>
  api.post<{ message: string }>(
    '/api/v1/auth/forgot-password',
    { email },
    { auth: false }
  );

export const resetPassword = (token: string, newPassword: string) =>
  api.post<{ message: string }>(
    '/api/v1/auth/reset-password',
    { token, newPassword },
    { auth: false }
  );

