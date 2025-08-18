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
    '/auth/login',
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
    '/auth/register',
    payload,
    { auth: false }
  );
  setAuthTokens({ accessToken: data.accessToken, refreshToken: data.refreshToken });
  return { user: data.user, company: data.company };
};

export const getProfile = () =>
  api.get<{ user: User; company: Company }>('/auth/me');

export const logout = async () => {
  await api.post('/auth/logout');
  clearAuthTokens();
};

