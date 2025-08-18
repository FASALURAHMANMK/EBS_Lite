import React, { createContext, useContext, useReducer, useEffect, ReactNode } from 'react';
import { DatabaseService } from '../services/database';
import { Location,User, Company, AuthState, AuthAction } from '../types/index';

const initialState: AuthState = {
  isAuthenticated: false,
  user: null,
  company: null,
  loading: false,
  error: null,
  isInitialized: false,
  databaseReady: false,
};


const authReducer = (state: AuthState, action: AuthAction): AuthState => {
  switch (action.type) {
    case 'AUTH_INIT_START':
      return { ...state, loading: true };
    case 'AUTH_INIT_COMPLETE':
      return { ...state, loading: false, isInitialized: true, databaseReady: true }; // Always mark DB ready
    case 'DATABASE_READY':
      return { ...state, databaseReady: true };
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
        databaseReady: true, // Mark ready on login success
      };
    case 'LOGIN_FAILURE':
    case 'REGISTER_FAILURE':
      return {
        ...state,
        loading: false,
        isAuthenticated: false,
        user: null,
        company: null,
        error: action.payload,
      };
    case 'LOGOUT':
      return {
        ...state,
        isAuthenticated: false,
        user: null,
        company: null,
        error: null,
        databaseReady: true, // Keep ready for next login
      };
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

export class AuthService {
  private static instance: AuthService;
  private db: DatabaseService | null = null;
  private isInitializing: boolean = false;

  private constructor() {
    // Don't initialize database here - do it lazily when needed
  }

  public static getInstance(): AuthService {
    if (!AuthService.instance) {
      AuthService.instance = new AuthService();
    }
    return AuthService.instance;
  }

private async getDatabase(): Promise<DatabaseService> {
  if (!this.db) {
    if (typeof window === 'undefined') {
      throw new Error('Database operations are not available during server-side rendering');
    }
    
    const config = {
      localDB: 'pos_local',
      remoteDB: 'http://127.0.0.1:5984', // Use your actual URL
      username: 'admin',
      password: 'admin'
    };

    console.log('🔧 Initializing database for auth operations...');
    
    this.db = DatabaseService.getInstance(config);
    
    // WAIT for initialization before proceeding with user operations
    if (!this.db.isInitializedStatus()) {
      console.log('⏳ Waiting for database initialization...');
      await this.db.initialize();
      
      // Additional wait for databases to be ready
      let retries = 0;
      while (!this.db.isInitializedStatus() && retries < 20) {
        await new Promise(resolve => setTimeout(resolve, 500));
        retries++;
      }
      
      if (!this.db.isInitializedStatus()) {
        throw new Error('Database initialization timeout');
      }
    }
  }
  
  return this.db;
}

  public async login(username: string, password: string): Promise<{ user: User; company: Company }> {
    try {
      const db = await this.getDatabase();
      const user = await db.authenticateUser(username, password);
      const company = await db.getCompanyData(user.companyId);
      
      if (!company) {
        throw new Error('Company not found');
      }

      if (!user.isActive) {
        throw new Error('User account is deactivated');
      }

      if (!company.isActive) {
        throw new Error('Company account is deactivated');
      }

      if (!company.locations) {
      const locations = await db.getCompanyLocations(company._id);
      company.locations = locations;
    }

      // Store session
      this.storeSession(user, company);

      return { user, company };
    } catch (error: any) {
      console.error('Login error:', error);
      throw new Error(error.message || 'Login failed');
    }
  }

  public async register(userData: {
    username: string;
    email: string;
    password: string;
    fullName: string;
    companyName: string;
    companyAddress: string;
    companyPhone: string;
    companyEmail: string;
  }): Promise<{ user: User; company: Company }> {
    try {
      const db = await this.getDatabase();
      
      // Create company first
      const companyData = {
        name: userData.companyName,
        address: userData.companyAddress,
        phone: userData.companyPhone,
        email: userData.companyEmail,
        settings: {
          currency: 'USD',
          timezone: 'UTC',
          dateFormat: 'DD/MM/YYYY',
          theme: 'light' as const
        }
      };

      const company = await db.createCompany(companyData);

      // Create admin user for the company
      const userToCreate = {
        username: userData.username,
        email: userData.email,
        password: userData.password,
        fullName: userData.fullName,
        role: 'admin' as const,
        companyId: company._id,
        permissions: ['all'],
      };

      const user = await db.createUser(userToCreate);

      // Remove password from response
      const { password: _, ...userWithoutPassword } = user;

      this.storeSession(userWithoutPassword, company);

      return { user: userWithoutPassword, company };
    } catch (error: any) {
      console.error('Registration error:', error);
      throw new Error(error.message || 'Registration failed');
    }
  }

  public logout(): void {
    if (typeof window !== 'undefined') {
      localStorage.removeItem('pos_auth_session');
      localStorage.removeItem('pos_user');
      localStorage.removeItem('pos_company');
    }
  }

  public getStoredSession(): { user: User; company: Company } | null {
    if (typeof window === 'undefined') {
      return null; // Return null during SSR
    }

    try {
      const user = localStorage.getItem('pos_user');
      const company = localStorage.getItem('pos_company');
      
      if (user && company) {
        return {
          user: JSON.parse(user),
          company: JSON.parse(company)
        };
      }
      return null;
    } catch {
      return null;
    }
  }

  private storeSession(user: User, company: Company): void {
    if (typeof window !== 'undefined') {
      localStorage.setItem('pos_auth_session', 'true');
      localStorage.setItem('pos_user', JSON.stringify(user));
      localStorage.setItem('pos_company', JSON.stringify(company));
    }
  }

  public async updateUser(userId: string, updates: Partial<User>): Promise<User> {
    const db = await this.getDatabase();
    const user = await db.findById('users', userId);
    if (!user) {
      throw new Error('User not found');
    }

    const updatedUser = { ...user, ...updates };
    return await db.update('users', updatedUser);
  }

  public async changePassword(userId: string, currentPassword: string, newPassword: string): Promise<void> {
    const db = await this.getDatabase();
    const user = await db.findById('users', userId);
    if (!user) {
      throw new Error('User not found');
    }

    // Verify current password
    const hashedCurrentPassword = await this.hashPassword(currentPassword);
    if (user.password !== hashedCurrentPassword) {
      throw new Error('Current password is incorrect');
    }

    // Update with new password
    user.password = await this.hashPassword(newPassword);
    await db.update('users', user);
  }

  private async hashPassword(password: string): Promise<string> {
    // Use a consistent hashing approach for both browser and server
    const salt = 'pos_salt_2025'; // Use a consistent salt
    const textToHash = password + salt;
    
    if (typeof crypto !== 'undefined' && crypto.subtle) {
      // Browser environment
      try {
        const encoder = new TextEncoder();
        const data = encoder.encode(textToHash);
        const hashBuffer = await crypto.subtle.digest('SHA-256', data);
        const hashArray = Array.from(new Uint8Array(hashBuffer));
        return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
      } catch (error) {
        console.warn('WebCrypto failed, falling back to simple hash');
        return this.simpleHash(textToHash);
      }
    } else {
      // Server environment or fallback
      return this.simpleHash(textToHash);
    }
  }
  
  // Add this helper method to both files
  private simpleHash(text: string): string {
    let hash = 0;
    if (text.length === 0) return hash.toString();
    
    for (let i = 0; i < text.length; i++) {
      const char = text.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash; // Convert to 32bit integer
    }
    
    // Convert to positive string and add some complexity
    const positiveHash = Math.abs(hash).toString(16);
    return `hash_${positiveHash}_${text.length}`;
  }

  // Add method to check database status
  public async getDatabaseStatus(): Promise<{ online: boolean; initialized: boolean }> {
    try {
      const db = await this.getDatabase();
      return {
        online: db.isOnlineStatus(),
        initialized: db.isInitializedStatus()
      };
    } catch {
      return {
        online: false,
        initialized: false
      };
    }
  }
}

interface AuthContextType {
  state: AuthState;
  login: (username: string, password: string) => Promise<void>;
  register: (userData: any) => Promise<void>;
  logout: () => void;
  clearError: () => void;
  updateUser: (updates: Partial<User>) => Promise<void>;
  updateCompany: (updates: Partial<Company>) => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const AuthProvider: React.FC<{ children: ReactNode }> = ({ children }) => {
  const [state, dispatch] = useReducer(authReducer, initialState);

  useEffect(() => {
    initializeAuth();
  }, []);

const initializeAuth = async () => {
  dispatch({ type: 'AUTH_INIT_START' });
  
  try {
    if (typeof window !== 'undefined') {
      const authService = AuthService.getInstance();
      
      // Check for stored session
      const session = authService.getStoredSession();
      if (session) {
        // Validate session has required fields
        if (session.user && session.company && session.company.locations) {
          dispatch({
            type: 'LOGIN_SUCCESS',
            payload: session
          });
        } else {
          console.warn('Stored session is incomplete, clearing...');
          authService.logout();
        }
      }
      
      // Initialize database in background regardless of session
      authService.getDatabaseStatus().catch(err => {
        console.log('Database not yet ready:', err);
      });
    }
  } catch (error) {
    console.error('Auth initialization error:', error);
  } finally {
    dispatch({ type: 'AUTH_INIT_COMPLETE' });
  }
};
const login = async (username: string, password: string) => {
  dispatch({ type: 'LOGIN_START' });
  try {
    const authService = AuthService.getInstance();
    
    // Perform authentication
    const result = await authService.login(username, password);

    // Ensure locations are loaded
    if (result.company && (!result.company.locations || result.company.locations.length === 0)) {
      try {
        const db = await (authService as any).getDatabase();
        const locations = await db.getCompanyLocations(result.company._id);
        result.company.locations = locations;
      } catch (error) {
        console.warn('Failed to load locations:', error);
        // Create a default location if none exist
        result.company.locations = [{
          _id: 'default',
          name: 'Main Location',
          code: 'LOC001',
          address: result.company.address,
          isActive: true,
          companyId: result.company._id,
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString()
        }];
      }
    }
    
    // Dispatch success
    dispatch({
      type: 'LOGIN_SUCCESS',
      payload: result
    });
    
  } catch (error: any) {
    dispatch({
      type: 'LOGIN_FAILURE',
      payload: error.message
    });
    throw error;
  }
};

const register = async (userData: any) => {
  dispatch({ type: 'REGISTER_START' });
  try {
    console.log('🚀 Starting registration process...');
    
    const authService = AuthService.getInstance();
    
    // Ensure database is ready
    console.log('⏳ Ensuring database is ready...');
    const db = await (authService as any).getDatabase();
    
    // Wait a moment for full initialization
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    console.log('📝 Creating user account...');
    const result = await authService.register(userData);
    
    // Ensure locations exist
    if (!result.company.locations || result.company.locations.length === 0) {
      console.log('🏪 Adding default location...');
      result.company.locations = [{
        _id: result.company._id + '_loc1',
        name: 'Main Location',
        code: 'LOC001',
        address: result.company.address,
        phone: result.company.phone,
        email: result.company.email,
        isActive: true,
        // isMainLocation: true,
        companyId: result.company._id,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString()
      }];
    }
    
    console.log('✅ Registration completed successfully');
    dispatch({
      type: 'REGISTER_SUCCESS',
      payload: result
    });
    
  } catch (error: any) {
    console.error('❌ Registration failed:', error);
    dispatch({
      type: 'REGISTER_FAILURE',
      payload: error.message
    });
    throw error;
  }
};

  const logout = () => {
    const authService = AuthService.getInstance();
    authService.logout();
    dispatch({ type: 'LOGOUT' });
  };

  const clearError = () => {
    dispatch({ type: 'CLEAR_ERROR' });
  };

  const updateUser = async (updates: Partial<User>) => {
    if (!state.user) return;
    
    try {
      const authService = AuthService.getInstance();
      const updatedUser = await authService.updateUser(state.user._id, updates);
      dispatch({ type: 'UPDATE_USER', payload: updatedUser });
      
      // Update localStorage
      if (typeof window !== 'undefined') {
        localStorage.setItem('pos_user', JSON.stringify(updatedUser));
      }
    } catch (error: any) {
      throw new Error(error.message);
    }
  };

  const updateCompany = async (updates: Partial<Company>) => {
    if (!state.company) return;
    
    try {
      const authService = AuthService.getInstance();
      const db = await (authService as any).getDatabase();
      const updatedCompany = await db.update('companies', { ...state.company, ...updates });
      dispatch({ type: 'UPDATE_COMPANY', payload: updatedCompany });
      
      // Update localStorage
      if (typeof window !== 'undefined') {
        localStorage.setItem('pos_company', JSON.stringify(updatedCompany));
      }
    } catch (error: any) {
      throw new Error(error.message);
    }
  };

  return (
    <AuthContext.Provider value={{
      state,
      login,
      register,
      logout,
      clearError,
      updateUser,
      updateCompany
    }}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};