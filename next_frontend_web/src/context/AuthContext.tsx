import React, { createContext, useContext, useReducer, useEffect, ReactNode } from 'react';
import { AuthState, AuthAction } from '../types';
import {
  login as loginService,
  register as registerService,
  getProfile,
  logout as logoutService,
} from '../services/auth';
import { getStoredAuthTokens } from '../services/apiClient';

interface AuthContextValue {
  state: AuthState;
  login: (username: string, password: string) => Promise<void>;
  register: (userData: any) => Promise<void>;
  logout: () => Promise<void>;
  clearError: () => void;
  hasRole: (roles: string | string[]) => boolean;
  hasPermission: (perms: string | string[]) => boolean;
  role?: string;
  permissions: string[];
  updateUserLanguages: (payload: {
    primaryLanguage: string;
    secondaryLanguage?: string;
  }) => void;
}

const initialState: AuthState = {
  isAuthenticated: false,
  user: null,
  company: null,
  loading: false,
  error: null,
  isInitialized: false,
};

const authReducer = (state: AuthState, action: AuthAction): AuthState => {
  switch (action.type) {
    case 'AUTH_INIT_START':
      return { ...state, loading: true };
    case 'AUTH_INIT_COMPLETE':
      return { ...state, loading: false, isInitialized: true };
    case 'LOGIN_START':
    case 'REGISTER_START':
      return { ...state, loading: true, error: null };
    case 'LOGIN_SUCCESS':
      return {
        ...state,
        loading: false,
        isAuthenticated: true,
        user: action.payload.user,
        company: action.payload.company,
        error: null,
      };
    case 'REGISTER_SUCCESS':
      return { ...state, loading: false, error: null };
    case 'LOGIN_FAILURE':
    case 'REGISTER_FAILURE':
      return { ...state, loading: false, error: action.payload };
    case 'LOGOUT':
      return { ...initialState, isInitialized: true };
    case 'CLEAR_ERROR':
      return { ...state, error: null };
    case 'UPDATE_USER_LANGUAGES':
      return state.user
        ? { ...state, user: { ...state.user, ...action.payload } }
        : state;
    default:
      return state;
  }
};
const AuthContext = createContext<AuthContextValue | null>(null);

const getDeviceId = (): string => {
  if (typeof window === 'undefined') return '';
  let id = localStorage.getItem('deviceId');
  if (!id) {
    const generate = () =>
      globalThis.crypto?.randomUUID?.() || Math.random().toString(36).slice(2);
    id = generate();
    localStorage.setItem('deviceId', id);
  }
  return id;
};

export const AuthProvider = ({ children }: { children: ReactNode }) => {
  const [state, dispatch] = useReducer(authReducer, initialState);

  useEffect(() => {
    const initialize = async () => {
      dispatch({ type: 'AUTH_INIT_START' });
      try {
        const { accessToken } = getStoredAuthTokens();
        if (accessToken) {
          const session = await getProfile();
          dispatch({ type: 'LOGIN_SUCCESS', payload: session });
        }
      } catch (err) {
        // not authenticated
      } finally {
        dispatch({ type: 'AUTH_INIT_COMPLETE' });
      }
    };
    initialize();
  }, []);

  const login = async (username: string, password: string) => {
    dispatch({ type: 'LOGIN_START' });
    try {
      const deviceId = getDeviceId();
      const data = await loginService(username, password, deviceId);
      dispatch({ type: 'LOGIN_SUCCESS', payload: data });
    } catch (err: any) {
      dispatch({ type: 'LOGIN_FAILURE', payload: err.message });
    }
  };

  const register = async (userData: any) => {
    dispatch({ type: 'REGISTER_START' });
    try {
      await registerService(userData);
      dispatch({ type: 'REGISTER_SUCCESS' });
    } catch (err: any) {
      dispatch({ type: 'REGISTER_FAILURE', payload: err.message });
    }
  };

  const logout = async () => {
    try {
      await logoutService();
    } finally {
      dispatch({ type: 'LOGOUT' });
    }
  };

  const clearError = () => dispatch({ type: 'CLEAR_ERROR' });

  const updateUserLanguages = (payload: { primaryLanguage: string; secondaryLanguage?: string }) => {
    dispatch({ type: 'UPDATE_USER_LANGUAGES', payload });
  };

  const role = state.user?.role;
  const permissions = state.user?.permissions || [];

  const hasRole = (roles: string | string[]) => {
    if (!role) return false;
    const roleList = Array.isArray(roles) ? roles : [roles];
    return roleList.map(r => r.toLowerCase()).includes(role.toLowerCase());
  };

  const hasPermission = (perms: string | string[]) => {
    if (!permissions.length) return false;
    const permList = Array.isArray(perms) ? perms : [perms];
    return permList.some(p => permissions.includes(p));
  };

  return (
    <AuthContext.Provider
      value={{
        state,
        login,
        register,
        logout,
        clearError,
        hasRole,
        hasPermission,
        role,
        permissions,
        updateUserLanguages,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};

