import React, { createContext, useContext, useReducer, useEffect, ReactNode } from 'react';
import { User, Company, AuthState, AuthAction } from '../types';

const initialState: AuthState = {
  isAuthenticated: false,
  user: null,
  company: null,
  loading: false,
  error: null,
  isInitialized: false,
  databaseReady: true,
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
    case 'UPDATE_USER':
      return { ...state, user: action.payload };
    case 'UPDATE_COMPANY':
      return { ...state, company: action.payload };
    default:
      return state;
  }
};

class AuthService {
  private static instance: AuthService;

  static getInstance(): AuthService {
    if (!AuthService.instance) {
      AuthService.instance = new AuthService();
    }
    return AuthService.instance;
  }

  private storeSession(user: User, company: Company) {
    if (typeof window !== 'undefined') {
      localStorage.setItem('auth_user', JSON.stringify(user));
      localStorage.setItem('auth_company', JSON.stringify(company));
    }
  }

  getCurrentSession(): { user: User; company: Company } | null {
    if (typeof window === 'undefined') return null;
    const user = localStorage.getItem('auth_user');
    const company = localStorage.getItem('auth_company');
    if (!user || !company) return null;
    return { user: JSON.parse(user), company: JSON.parse(company) };
  }

  clearSession() {
    if (typeof window !== 'undefined') {
      localStorage.removeItem('auth_user');
      localStorage.removeItem('auth_company');
    }
  }

  async login(username: string, password: string): Promise<{ user: User; company: Company }> {
    const response = await fetch('/api/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username, password }),
    });
    if (!response.ok) {
      throw new Error('Login failed');
    }
    const data = await response.json();
    this.storeSession(data.user, data.company);
    return data;
  }

  async register(userData: {
    username: string;
    email: string;
    password: string;
    fullName: string;
    companyName: string;
    companyAddress: string;
    companyPhone: string;
    companyEmail: string;
  }): Promise<{ user: User; company: Company }> {
    const response = await fetch('/api/register', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(userData),
    });
    if (!response.ok) {
      throw new Error('Registration failed');
    }
    const data = await response.json();
    this.storeSession(data.user, data.company);
    return data;
  }

  async updateUser(userId: string, updates: Partial<User>): Promise<User> {
    const response = await fetch(`/api/users/${userId}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(updates),
    });
    if (!response.ok) {
      throw new Error('Update failed');
    }
    return await response.json();
  }

  async updateCompany(companyId: string, updates: Partial<Company>): Promise<Company> {
    const response = await fetch(`/api/companies/${companyId}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(updates),
    });
    if (!response.ok) {
      throw new Error('Update failed');
    }
    return await response.json();
  }
}

const AuthContext = createContext<any>(null);

export const AuthProvider = ({ children }: { children: ReactNode }) => {
  const [state, dispatch] = useReducer(authReducer, initialState);
  const authService = AuthService.getInstance();

  useEffect(() => {
    dispatch({ type: 'AUTH_INIT_START' });
    const session = authService.getCurrentSession();
    if (session) {
      dispatch({ type: 'LOGIN_SUCCESS', payload: session });
    }
    dispatch({ type: 'AUTH_INIT_COMPLETE' });
  }, []);

  const login = async (username: string, password: string) => {
    dispatch({ type: 'LOGIN_START' });
    try {
      const data = await authService.login(username, password);
      dispatch({ type: 'LOGIN_SUCCESS', payload: data });
    } catch (err: any) {
      dispatch({ type: 'LOGIN_FAILURE', payload: err.message });
    }
  };

  const register = async (userData: any) => {
    dispatch({ type: 'REGISTER_START' });
    try {
      const data = await authService.register(userData);
      dispatch({ type: 'REGISTER_SUCCESS', payload: data });
    } catch (err: any) {
      dispatch({ type: 'REGISTER_FAILURE', payload: err.message });
    }
  };

  const logout = () => {
    authService.clearSession();
    dispatch({ type: 'LOGOUT' });
  };

  const clearError = () => dispatch({ type: 'CLEAR_ERROR' });

  const updateUser = async (updates: Partial<User>) => {
    if (!state.user) return;
    const updated = await authService.updateUser(state.user._id, updates);
    dispatch({ type: 'UPDATE_USER', payload: updated });
  };

  const updateCompany = async (updates: Partial<Company>) => {
    if (!state.company) return;
    const updated = await authService.updateCompany(state.company._id, updates);
    dispatch({ type: 'UPDATE_COMPANY', payload: updated });
  };

  return (
    <AuthContext.Provider value={{ state, login, register, logout, clearError, updateUser, updateCompany }}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => useContext(AuthContext);

