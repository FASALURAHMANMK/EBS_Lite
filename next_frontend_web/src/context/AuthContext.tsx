import React, { createContext, useContext, useReducer, useEffect, ReactNode } from 'react';
import { AuthState, AuthAction } from '../types';
import { login as loginService, register as registerService, getProfile, logout as logoutService } from '../services/auth';

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
    case 'REGISTER_SUCCESS':
      return {
        ...state,
        loading: false,
        isAuthenticated: true,
        user: action.payload.user,
        company: action.payload.company,
        error: null,
      };
    case 'LOGIN_FAILURE':
    case 'REGISTER_FAILURE':
      return { ...state, loading: false, error: action.payload };
    case 'LOGOUT':
      return { ...initialState, isInitialized: true };
    case 'CLEAR_ERROR':
      return { ...state, error: null };
    default:
      return state;
  }
};
const AuthContext = createContext<any>(null);

export const AuthProvider = ({ children }: { children: ReactNode }) => {
  const [state, dispatch] = useReducer(authReducer, initialState);

  useEffect(() => {
    const initialize = async () => {
      dispatch({ type: 'AUTH_INIT_START' });
      try {
        const session = await getProfile();
        dispatch({ type: 'LOGIN_SUCCESS', payload: session });
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
      const data = await loginService(username, password);
      dispatch({ type: 'LOGIN_SUCCESS', payload: data });
    } catch (err: any) {
      dispatch({ type: 'LOGIN_FAILURE', payload: err.message });
    }
  };

  const register = async (userData: any) => {
    dispatch({ type: 'REGISTER_START' });
    try {
      const data = await registerService(userData);
      dispatch({ type: 'REGISTER_SUCCESS', payload: data });
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

  return (
    <AuthContext.Provider value={{ state, login, register, logout, clearError }}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => useContext(AuthContext);

