import api, { setAuthTokens, clearAuthTokens } from './apiClient';
import { User, Company } from '../types';

/**
 * Payload sent to the backend when a user attempts to log in.
 * The keys here use camelCase but are converted to snake_case
 * automatically by {@link api}.
 */
interface LoginPayload {
  email: string;
  password: string;
  deviceId: string;
}

/**
 * Structure returned by the authentication endpoints. All tokens
 * are persisted via {@link setAuthTokens} and the sessionId can be
 * used by the client for device session management.
 */
export interface AuthResponse {
  accessToken: string;
  refreshToken: string;
  sessionId: string;
  user: User;
  company: Company;
}

/**
 * Response returned after a successful registration.
 * Only confirmation details are provided; tokens are not issued
 * until the user explicitly logs in.
 */
export interface RegisterResponse {
  userId: number;
  username: string;
  email: string;
  message: string;
}

export const login = async (
  email: string,
  password: string,
  deviceId: string
): Promise<{ user: User; company: Company; sessionId: string }> => {
  const payload: LoginPayload = { email, password, deviceId };
  const data = await api.post<AuthResponse>(
    '/api/v1/auth/login',
    payload,
    { auth: false }
  );
  setAuthTokens({ accessToken: data.accessToken, refreshToken: data.refreshToken });
  return { user: data.user, company: data.company, sessionId: data.sessionId };
};

export const register = async (
  payload: Record<string, any>
): Promise<RegisterResponse> =>
  api.post<RegisterResponse>(
    '/api/v1/auth/register',
    payload,
    { auth: false }
  );

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

