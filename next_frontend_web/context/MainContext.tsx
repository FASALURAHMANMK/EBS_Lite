import React, { createContext, useContext, useReducer, ReactNode, useEffect, useRef, useCallback } from 'react';
import { DatabaseService } from '../services/database';
import { useAuth } from './AuthContext';
import { Location, Product, Category, Customer, Supplier, Sale, CreditTransaction, AppState, AppAction } from '../types/index';


const initialState: AppState = {
  currentView: 'dashboard',
  selectedCategory: 'All',
  isLoading: false,
  isInitialized: false,
  error: null,
  currentLocationId: null,
  cart: [],
  customer: { phone: '', name: '', creditBalance: 0, address: '' },
  products: [],
  categories: ['All'],
  customers: [],
  suppliers: [],
  recentSales: [],
  isSyncing: false,
  lastSyncTime: null,
  syncStatus: 'offline',
  theme: 'light',
  sidebarCollapsed: false,
  currentPage: 1,
  itemsPerPage: 20,
  totalItems: 0,
};

const appReducer = (state: AppState, action: AppAction): AppState => {
  switch (action.type) {
    case 'SET_CURRENT_LOCATION':
      return { ...state, currentLocationId: action.payload };
    case 'SET_LOADING':
      return { ...state, isLoading: action.payload };
    case 'SET_INITIALIZED':
      return { ...state, isInitialized: action.payload };
    case 'SET_ERROR':
      return { ...state, error: action.payload };
    case 'SET_VIEW':
      return { ...state, currentView: action.payload };
    case 'SET_CATEGORY':
      return { ...state, selectedCategory: action.payload };
    case 'SET_PRODUCTS':
      return { ...state, products: action.payload };
    case 'ADD_PRODUCT':
      return { ...state, products: [...state.products, action.payload] };
    case 'UPDATE_PRODUCT':
      return {
        ...state,
        products: state.products.map(p => p._id === action.payload._id ? action.payload : p)
      };
    case 'DELETE_PRODUCT':
      return {
        ...state,
        products: state.products.filter(p => p._id !== action.payload)
      };
    case 'SET_CATEGORIES':
      return { ...state, categories: action.payload };
    case 'ADD_CATEGORY':
      return { ...state, categories: [...state.categories, action.payload] };
    case 'SET_CUSTOMERS':
      return { ...state, customers: action.payload };
    case 'ADD_CUSTOMER':
      return { ...state, customers: [...state.customers, action.payload] };
    case 'UPDATE_CUSTOMER':
      return {
        ...state,
        customers: state.customers.map(c => c._id === action.payload._id ? action.payload : c)
      };
    case 'DELETE_CUSTOMER':
      return {
        ...state,
        customers: state.customers.filter(c => c._id !== action.payload)
      };
    case 'SET_SUPPLIERS':
      return { ...state, suppliers: action.payload };
    case 'ADD_SUPPLIER':
      return { ...state, suppliers: [...state.suppliers, action.payload] };
    case 'UPDATE_SUPPLIER':
      return {
        ...state,
        suppliers: state.suppliers.map(s => s._id === action.payload._id ? action.payload : s)
      };
    case 'DELETE_SUPPLIER':
      return {
        ...state,
        suppliers: state.suppliers.filter(s => s._id !== action.payload)
      };
    case 'ADD_TO_CART':
      const existingItem = state.cart.find(item => item.product._id === action.payload._id);
      if (existingItem) {
        return {
          ...state,
          cart: state.cart.map(item =>
            item.product._id === action.payload._id
              ? { 
                  ...item, 
                  quantity: item.quantity + 1, 
                  totalPrice: (item.quantity + 1) * item.unitPrice 
                }
              : item
          )
        };
      } else {
        return {
          ...state,
          cart: [...state.cart, {
            product: action.payload,
            quantity: 1,
            unitPrice: action.payload.price,
            totalPrice: action.payload.price
          }]
        };
      }
    case 'REMOVE_FROM_CART':
      return {
        ...state,
        cart: state.cart.filter(item => item.product._id !== action.payload)
      };
    case 'UPDATE_CART_QUANTITY':
      if (action.payload.quantity <= 0) {
        return {
          ...state,
          cart: state.cart.filter(item => item.product._id !== action.payload.id)
        };
      }
      return {
        ...state,
        cart: state.cart.map(item =>
          item.product._id === action.payload.id
            ? { 
                ...item, 
                quantity: action.payload.quantity, 
                totalPrice: action.payload.quantity * item.unitPrice 
              }
            : item
        )
      };
    case 'CLEAR_CART':
      return { 
        ...state, 
        cart: [], 
        customer: { phone: '', name: '', creditBalance: 0, address: '' } 
      };
    case 'SET_CUSTOMER':
      return { ...state, customer: { ...state.customer, ...action.payload } };
    case 'SET_RECENT_SALES':
      return { ...state, recentSales: action.payload };
    case 'ADD_SALE':
      return { ...state, recentSales: [action.payload, ...state.recentSales.slice(0, 9)] };
    case 'SET_SYNC_STATUS':
      return {
        ...state,
        syncStatus: action.payload.status,
        isSyncing: action.payload.isSyncing,
        lastSyncTime: action.payload.lastSyncTime || state.lastSyncTime
      };
    case 'TOGGLE_THEME':
      return { ...state, theme: state.theme === 'light' ? 'dark' : 'light' };
    case 'SET_THEME':
      return { ...state, theme: action.payload };
    case 'TOGGLE_SIDEBAR':
      return { ...state, sidebarCollapsed: !state.sidebarCollapsed };
    case 'SET_PAGINATION':
      return { 
        ...state, 
        currentPage: action.payload.currentPage, 
        totalItems: action.payload.totalItems 
      };
    case 'RESET_STATE':
      return {
        ...initialState,
        theme: state.theme, // Preserve theme preference
        sidebarCollapsed: state.sidebarCollapsed // Preserve sidebar state
      };
    default:
      return state;
  }
};

interface POSContextType {
  state: AppState;
  dispatch: React.Dispatch<AppAction>;
  
  // Database methods
  loadAllData: () => Promise<void>;
  loadAllDataSilently: () => Promise<void>;
  setCurrentLocation: (locationId: string) => Promise<void>;
  createLocation: (locationData: Partial<Location>) => Promise<Location>;
  updateLocation: (locationId: string, updates: Partial<Location>) => Promise<Location>;
  deleteLocation: (locationId: string) => Promise<void>;
  getAvailableLocations: () => Promise<Location[]>;
  getCurrentLocation: () => Location | null;
  
  loadProducts: () => Promise<void>;
  createProduct: (productData: Partial<Product>) => Promise<Product>;
  updateProduct: (productId: string, updates: Partial<Product>) => Promise<Product>;
  deleteProduct: (productId: string) => Promise<void>;
  
  loadCategories: () => Promise<void>;
  createCategory: (categoryData: { name: string; description?: string }) => Promise<Category>;
  updateCategory: (categoryId: string, updates: Partial<Category>) => Promise<Category>;
  deleteCategory: (categoryId: string) => Promise<void>;
  
  loadCustomers: () => Promise<void>;
  createCustomer: (customerData: Partial<Customer>) => Promise<Customer>;
  updateCustomer: (customerId: string, updates: Partial<Customer>) => Promise<Customer>;
  deleteCustomer: (customerId: string) => Promise<void>;
  updateCustomerCredit: (customerId: string, amount: number, type: 'credit' | 'debit', description: string) => Promise<void>;
  getCustomerCreditHistory: (customerId: string) => Promise<CreditTransaction[]>;
  
  loadSuppliers: () => Promise<void>;
  createSupplier: (supplierData: Partial<Supplier>) => Promise<Supplier>;
  updateSupplier: (supplierId: string, updates: Partial<Supplier>) => Promise<Supplier>;
  deleteSupplier: (supplierId: string) => Promise<void>;
  
  loadRecentSales: () => Promise<void>;
  createSale: (saleData: Partial<Sale>) => Promise<Sale>;
  
  searchProducts: (query: string) => Product[];
  searchCustomers: (query: string) => Customer[];
  getProductsByCategory: (category: string) => Product[];
  
  getDashboardStats: () => Promise<any>;
}

const POSContext = createContext<POSContextType | undefined>(undefined);

export const POSProvider: React.FC<{ children: ReactNode }> = ({ children }) => {
  const [state, dispatch] = useReducer(appReducer, initialState);
  const { state: authState } = useAuth();
  const debouncedDataRefresh = useRef<NodeJS.Timeout | null>(null);
  const syncEventListenerRef = useRef<((event: any) => void) | null>(null);
  const initializationPromiseRef = useRef<Promise<void> | null>(null);

  // Helper function to ensure required data
  const ensureRequiredData = () => {
    if (!authState.user?.companyId) {
      throw new Error('No company ID available. Please log in again.');
    }
    if (!state.currentLocationId) {
      throw new Error('No location selected. Please select a location.');
    }
    return {
      companyId: authState.user.companyId,
      locationId: state.currentLocationId,
      userId: authState.user._id
    };
  };

  // Check if we have minimum required data for operations
  const hasRequiredData = () => {
    return authState.user?.companyId && state.currentLocationId;
  };

  // Database service getter with proper error handling
  const getDatabaseService = (): DatabaseService => {
    try {
      const db = DatabaseService.getInstance();
      if (!db) {
        throw new Error('Database service not available');
      }
      return db;
    } catch (error) {
      console.error('Error getting database service:', error);
      throw new Error('Database service unavailable. Please refresh the page.');
    }
  };

  // Wait for database initialization
  const waitForDatabase = async (maxRetries = 20): Promise<DatabaseService> => {
    const db = getDatabaseService();
    let retries = 0;
    
    while (!db.isInitializedStatus() && retries < maxRetries) {
      console.log(`Waiting for database initialization... (${retries + 1}/${maxRetries})`);
      await new Promise(resolve => setTimeout(resolve, 500));
      retries++;
    }
    
    if (!db.isInitializedStatus()) {
      throw new Error('Database initialization timeout. Please refresh the page.');
    }
    
    return db;
  };

  // Reset state when user logs out or company changes
  useEffect(() => {
    if (!authState.isAuthenticated) {
      dispatch({ type: 'RESET_STATE' });
      initializationPromiseRef.current = null;
    }
  }, [authState.isAuthenticated]);

  // Initialize location
  useEffect(() => {
    if (typeof window !== 'undefined' && authState.company?.locations?.length > 0 && !state.currentLocationId) {
      const savedLocation = localStorage.getItem('pos_current_location');
      const validLocation = savedLocation && authState.company.locations.some(loc => loc._id === savedLocation);
      
      const locationToUse = validLocation ? savedLocation : authState.company.locations[0]._id;
      dispatch({ type: 'SET_CURRENT_LOCATION', payload: locationToUse });
      localStorage.setItem('pos_current_location', locationToUse);
    }
  }, [authState.company?.locations, state.currentLocationId]);

  // Initialize theme
  useEffect(() => {
    if (typeof window !== 'undefined') {
      const savedTheme = localStorage.getItem('pos-theme') as 'light' | 'dark' | null;
      if (savedTheme) {
        dispatch({ type: 'SET_THEME', payload: savedTheme });
      }
    }
  }, []);

  // Apply theme
  useEffect(() => {
    if (typeof window !== 'undefined') {
      localStorage.setItem('pos-theme', state.theme);
      document.documentElement.classList.remove('light', 'dark');
      document.documentElement.classList.add(state.theme);
    }
  }, [state.theme]);

  // Handle sync events
  const handleSyncEvent = useCallback(async (event: CustomEvent) => {
    const { type, dbName, data } = event.detail;
    
    console.log('🔄 Sync event:', { type, dbName, data });

    // Clear any existing debounce timeout
    if (debouncedDataRefresh.current) {
      clearTimeout(debouncedDataRefresh.current);
    }

    switch (type) {
      case 'realtime_change':
      case 'sync_change':
        dispatch({ 
          type: 'SET_SYNC_STATUS', 
          payload: { 
            status: 'online', 
            isSyncing: true,
            lastSyncTime: new Date().toISOString()
          } 
        });
        
        // Debounced refresh
        debouncedDataRefresh.current = setTimeout(async () => {
          try {
            await refreshDataForDatabase(dbName);
            dispatch({ 
              type: 'SET_SYNC_STATUS', 
              payload: { 
                status: 'online', 
                isSyncing: false,
                lastSyncTime: new Date().toISOString()
              } 
            });
          } catch (error) {
            console.error(`Failed to refresh ${dbName}:`, error);
          }
        }, 300);
        break;

      case 'sync_active':
        dispatch({ 
          type: 'SET_SYNC_STATUS', 
          payload: { 
            status: 'online', 
            isSyncing: true
          } 
        });
        break;

      case 'sync_complete':
      case 'sync_success':
        dispatch({ 
          type: 'SET_SYNC_STATUS', 
          payload: { 
            status: 'online', 
            isSyncing: false,
            lastSyncTime: new Date().toISOString()
          } 
        });
        setTimeout(() => loadAllDataSilently(), 100);
        break;

      case 'online':
        dispatch({ 
          type: 'SET_SYNC_STATUS', 
          payload: { 
            status: 'online', 
            isSyncing: false,
            lastSyncTime: new Date().toISOString()
          } 
        });
        dispatch({ type: 'SET_ERROR', payload: null });
        setTimeout(() => loadAllDataSilently(), 500);
        break;

      case 'offline':
      case 'connection_lost':
        dispatch({ 
          type: 'SET_SYNC_STATUS', 
          payload: { 
            status: 'offline', 
            isSyncing: false
          } 
        });
        break;
        
      case 'sync_error':
        const isConnectionError = data?.error?.includes('ECONNREFUSED') || 
                                  data?.error?.includes('timeout') || 
                                  data?.error?.includes('fetch');
        
        dispatch({ 
          type: 'SET_SYNC_STATUS', 
          payload: { 
            status: isConnectionError ? 'offline' : 'error', 
            isSyncing: false
          } 
        });
        
        if (!isConnectionError) {
          dispatch({ type: 'SET_ERROR', payload: `Sync issue: ${data.error}` });
        }
        break;
        
      case 'initialized':
        console.log('📦 Database initialized event received');
        // Don't immediately initialize - let the effect hook handle it
        break;
    }
  }, []);

  // Setup sync listeners
  const setupSyncListeners = useCallback(() => {
    if (typeof window !== 'undefined') {
      // Remove existing listener if any
      if (syncEventListenerRef.current) {
        window.removeEventListener('db-sync', syncEventListenerRef.current);
      }
      
      // Create and store new listener
      syncEventListenerRef.current = handleSyncEvent as any;
      window.addEventListener('db-sync', syncEventListenerRef.current);
    }
  }, [handleSyncEvent]);

  // Initialize data and listeners
  useEffect(() => {
    const shouldInitialize = authState.isAuthenticated && 
                           authState.user?.companyId && 
                           authState.databaseReady && 
                           state.currentLocationId &&
                           !state.isInitialized &&
                           !state.isLoading;

    if (shouldInitialize) {
      // Delay initialization slightly to ensure all auth data is ready
      const initTimer = setTimeout(() => {
        // Double-check conditions before initializing
        if (authState.user?.companyId && state.currentLocationId) {
          if (!initializationPromiseRef.current) {
            initializationPromiseRef.current = initializeData();
          }
        }
      }, 100);

      setupSyncListeners();

      return () => {
        clearTimeout(initTimer);
        if (debouncedDataRefresh.current) {
          clearTimeout(debouncedDataRefresh.current);
        }
        if (typeof window !== 'undefined' && syncEventListenerRef.current) {
          window.removeEventListener('db-sync', syncEventListenerRef.current);
        }
      };
    }
  }, [
    authState.isAuthenticated, 
    authState.user?.companyId, 
    authState.databaseReady, 
    state.currentLocationId,
    state.isInitialized,
    state.isLoading,
    setupSyncListeners
  ]);

  // Initialize data
  const initializeData = async () => {
    // Don't initialize if already initialized or loading
    if (state.isInitialized || state.isLoading) {
      console.log('Already initialized or loading, skipping...');
      return;
    }

    // Check if we have the required data before proceeding
    if (!authState.user?.companyId || !state.currentLocationId) {
      console.log('Waiting for auth data or location...', {
        hasUser: !!authState.user,
        hasCompanyId: !!authState.user?.companyId,
        hasLocation: !!state.currentLocationId
      });
      return;
    }

    dispatch({ type: 'SET_LOADING', payload: true });
    dispatch({ type: 'SET_ERROR', payload: null });
    
    try {
      console.log('🚀 Starting POS data initialization...');
      
      const db = await waitForDatabase();

      console.log('✅ Database ready, loading application data...');

      const loadOperations = [
        { name: 'categories', fn: loadCategories },
        { name: 'products', fn: loadProducts },
        { name: 'customers', fn: loadCustomers },
        { name: 'suppliers', fn: loadSuppliers },
        { name: 'recent sales', fn: loadRecentSales }
      ];

      const results = await Promise.allSettled(
        loadOperations.map(op => op.fn())
      );

      const failedOperations = loadOperations
        .filter((_, index) => results[index].status === 'rejected')
        .map(op => op.name);

      if (failedOperations.length > 0) {
        console.warn(`⚠️ Some data failed to load: ${failedOperations.join(', ')}`);
        dispatch({ 
          type: 'SET_ERROR', 
          payload: `Some data failed to load: ${failedOperations.join(', ')}. You can still use the app.` 
        });
      }

      dispatch({ type: 'SET_INITIALIZED', payload: true });
      
      const isOnline = db.isOnlineStatus();
      dispatch({ 
        type: 'SET_SYNC_STATUS', 
        payload: { 
          status: isOnline ? 'online' : 'offline', 
          isSyncing: false,
          lastSyncTime: new Date().toISOString()
        } 
      });

      console.log('✅ POS application initialized successfully');
      
    } catch (error: any) {
      console.error('❌ Critical error during initialization:', error);
      dispatch({ type: 'SET_ERROR', payload: error.message });
      dispatch({ type: 'SET_INITIALIZED', payload: false });
    } finally {
      dispatch({ type: 'SET_LOADING', payload: false });
      initializationPromiseRef.current = null;
    }
  };

  // Refresh specific database data
  const refreshDataForDatabase = async (dbName: string) => {
    if (!hasRequiredData()) {
      console.warn('No location or company selected, skipping refresh');
      return;
    }

    try {
      console.log(`🔄 Refreshing ${dbName} data...`);
      
      switch (dbName) {
        case 'products':
          await loadProducts();
          break;
        case 'customers':
          await loadCustomers();
          break;
        case 'categories':
          await loadCategories();
          break;
        case 'suppliers':
          await loadSuppliers();
          break;
        case 'sales':
          await loadRecentSales();
          break;
        case 'companies':
        case 'locations':
          // Skip - handled by auth context
          console.log('Company/Location changes handled by auth context');
          break;
        default:
          console.log(`No refresh handler for database: ${dbName}`);
      }
    } catch (error: any) {
      console.error(`❌ Failed to refresh ${dbName}:`, error);
    }
  };

  // Load all data silently
  const loadAllDataSilently = async () => {
    if (!state.currentLocationId || !authState.user?.companyId) {
      console.warn('Missing required data for silent refresh');
      return;
    }

    try {
      await Promise.allSettled([
        loadCategories(),
        loadProducts(),
        loadCustomers(),
        loadSuppliers(),
        loadRecentSales()
      ]);
      console.log('✅ Silent data refresh completed');
    } catch (error) {
      console.error('❌ Silent data refresh failed:', error);
    }
  };

  // Load all data with UI feedback
  const loadAllData = async () => {
    if (!hasRequiredData()) {
      console.warn('Missing required data for loading');
      return;
    }

    dispatch({ type: 'SET_LOADING', payload: true });
    dispatch({ type: 'SET_ERROR', payload: null });
    
    try {
      await loadAllDataSilently();
    } catch (error: any) {
      dispatch({ type: 'SET_ERROR', payload: error.message });
    } finally {
      dispatch({ type: 'SET_LOADING', payload: false });
    }
  };

  // Set current location
  const setCurrentLocation = async (locationId: string) => {
    try {
      dispatch({ type: 'SET_LOADING', payload: true });
      dispatch({ type: 'SET_CURRENT_LOCATION', payload: locationId });
      
      if (typeof window !== 'undefined') {
        localStorage.setItem('pos_current_location', locationId);
      }
      
      // Clear existing data first
      dispatch({ type: 'SET_PRODUCTS', payload: [] });
      dispatch({ type: 'SET_CUSTOMERS', payload: [] });
      dispatch({ type: 'SET_SUPPLIERS', payload: [] });
      dispatch({ type: 'SET_CATEGORIES', payload: ['All'] });
      dispatch({ type: 'SET_RECENT_SALES', payload: [] });
      
      // Load data for new location
      await loadAllDataSilently();
      
      console.log(`✅ Successfully switched to location: ${locationId}`);
    } catch (error: any) {
      console.error('Error switching location:', error);
      dispatch({ type: 'SET_ERROR', payload: `Failed to switch location: ${error.message}` });
    } finally {
      dispatch({ type: 'SET_LOADING', payload: false });
    }
  };

  // Location management
  const getAvailableLocations = async (): Promise<Location[]> => {
    return authState.company?.locations || [];
  };

  const getCurrentLocation = (): Location | null => {
    if (!state.currentLocationId || !authState.company?.locations) return null;
    return authState.company.locations.find(loc => loc._id === state.currentLocationId) || null;
  };

  const createLocation = async (locationData: Partial<Location>): Promise<Location> => {
    const db = getDatabaseService();
    const { companyId } = ensureRequiredData();

    const newLocation = await db.createLocation({
      ...locationData,
      companyId,
    });

    return newLocation;
  };

  const updateLocation = async (locationId: string, updates: Partial<Location>): Promise<Location> => {
    const db = getDatabaseService();
    const location = await db.findById('locations', locationId);
    if (!location) throw new Error('Location not found');

    const updatedLocation = await db.update('locations', { ...location, ...updates });
    return updatedLocation;
  };

  const deleteLocation = async (locationId: string): Promise<void> => {
    await updateLocation(locationId, { isActive: false });
  };

  // Product management
  const loadProducts = async () => {
    if (!state.currentLocationId || !authState.user?.companyId) {
      console.log('Missing required data for loading products');
      return;
    }

    try {
      const db = await waitForDatabase();
      const products = await db.find('products', {
        selector: { 
          companyId: authState.user.companyId,
          locationId: state.currentLocationId,
          isActive: true 
        }
      });

      console.log(`Loaded ${products.length} products`);
      dispatch({ type: 'SET_PRODUCTS', payload: products });
    } catch (error: any) {
      console.error('Error loading products:', error);
      dispatch({ type: 'SET_ERROR', payload: `Failed to load products: ${error.message}` });
      dispatch({ type: 'SET_PRODUCTS', payload: [] });
    }
  };

  const createProduct = async (productData: Partial<Product>): Promise<Product> => {
    const db = getDatabaseService();
    const { companyId, locationId } = ensureRequiredData();

    const newProduct = await db.create('products', {
      ...productData,
      companyId,
      locationId,
      isActive: true,
      sku: productData.sku || `SKU-${Date.now()}`,
    });

    dispatch({ type: 'ADD_PRODUCT', payload: newProduct });
    return newProduct;
  };

  const updateProduct = async (productId: string, updates: Partial<Product>): Promise<Product> => {
    const db = getDatabaseService();
    const product = await db.findById('products', productId);
    if (!product) throw new Error('Product not found');

    const updatedProduct = await db.update('products', { ...product, ...updates });
    dispatch({ type: 'UPDATE_PRODUCT', payload: updatedProduct });
    return updatedProduct;
  };

  const deleteProduct = async (productId: string): Promise<void> => {
    await updateProduct(productId, { isActive: false });
    dispatch({ type: 'DELETE_PRODUCT', payload: productId });
  };

  // Category management
  const loadCategories = async () => {
    if (!state.currentLocationId || !authState.user?.companyId) {
      console.log('Missing required data for loading categories');
      return;
    }

    try {
      const db = await waitForDatabase();
      const categories = await db.find('categories', {
        selector: { 
          companyId: authState.user.companyId,
          locationId: state.currentLocationId,
          isActive: true 
        }
      });

      console.log(`Loaded ${categories.length} categories`);
      const categoryNames = ['All', ...categories.map((cat: Category) => cat.name)];
      dispatch({ type: 'SET_CATEGORIES', payload: categoryNames });
    } catch (error: any) {
      console.error('Error loading categories:', error);
      dispatch({ type: 'SET_ERROR', payload: `Failed to load categories: ${error.message}` });
      dispatch({ type: 'SET_CATEGORIES', payload: ['All'] });
    }
  };

  const createCategory = async (categoryData: { name: string; description?: string }): Promise<Category> => {
    const db = getDatabaseService();
    const { companyId, locationId } = ensureRequiredData();

    const newCategory = await db.create('categories', {
      ...categoryData,
      companyId,
      locationId,
      isActive: true,
    });

    dispatch({ type: 'ADD_CATEGORY', payload: newCategory.name });
    return newCategory;
  };

  const updateCategory = async (categoryId: string, updates: Partial<Category>): Promise<Category> => {
    const db = getDatabaseService();
    const category = await db.findById('categories', categoryId);
    if (!category) throw new Error('Category not found');

    const updatedCategory = await db.update('categories', { ...category, ...updates });
    await loadCategories();
    return updatedCategory;
  };

  const deleteCategory = async (categoryId: string): Promise<void> => {
    await updateCategory(categoryId, { isActive: false });
    await loadCategories();
  };

  // Customer management
  const loadCustomers = async () => {
    if (!state.currentLocationId || !authState.user?.companyId) {
      console.log('Missing required data for loading customers');
      return;
    }

    try {
      const db = await waitForDatabase();
      const customers = await db.find('customers', {
        selector: { 
          companyId: authState.user.companyId,
          locationId: state.currentLocationId,
          isActive: true 
        }
      });

      console.log(`Loaded ${customers.length} customers`);
      dispatch({ type: 'SET_CUSTOMERS', payload: customers });
    } catch (error: any) {
      console.error('Error loading customers:', error);
      dispatch({ type: 'SET_ERROR', payload: `Failed to load customers: ${error.message}` });
      dispatch({ type: 'SET_CUSTOMERS', payload: [] });
    }
  };

  const createCustomer = async (customerData: Partial<Customer>): Promise<Customer> => {
    const db = getDatabaseService();
    const { companyId, locationId } = ensureRequiredData();

    const newCustomer = await db.create('customers', {
      ...customerData,
      companyId,
      locationId,
      isActive: true,
      creditBalance: customerData.creditBalance || 0,
      creditLimit: customerData.creditLimit || 0,
      loyaltyPoints: customerData.loyaltyPoints || 0,
    });

    dispatch({ type: 'ADD_CUSTOMER', payload: newCustomer });
    return newCustomer;
  };

  const updateCustomer = async (customerId: string, updates: Partial<Customer>): Promise<Customer> => {
    const db = getDatabaseService();
    const customer = await db.findById('customers', customerId);
    if (!customer) throw new Error('Customer not found');

    const updatedCustomer = await db.update('customers', { ...customer, ...updates });
    dispatch({ type: 'UPDATE_CUSTOMER', payload: updatedCustomer });
    return updatedCustomer;
  };

  const deleteCustomer = async (customerId: string): Promise<void> => {
    await updateCustomer(customerId, { isActive: false });
    dispatch({ type: 'DELETE_CUSTOMER', payload: customerId });
  };

  const updateCustomerCredit = async (
    customerId: string, 
    amount: number, 
    type: 'credit' | 'debit', 
    description: string
  ): Promise<void> => {
    const db = getDatabaseService();
    await db.updateCustomerCredit(customerId, amount, type, description);
    await loadCustomers();
  };

  const getCustomerCreditHistory = async (customerId: string): Promise<CreditTransaction[]> => {
    try {
      const db = getDatabaseService();
      return await db.getCustomerCreditHistory(customerId);
    } catch (error: any) {
      console.error('Error loading credit history:', error);
      return [];
    }
  };

  // Supplier management
  const loadSuppliers = async () => {
    if (!state.currentLocationId || !authState.user?.companyId) {
      console.log('Missing required data for loading suppliers');
      return;
    }

    try {
      const db = await waitForDatabase();
      const suppliers = await db.find('suppliers', {
        selector: { 
          companyId: authState.user.companyId,
          locationId: state.currentLocationId,
          isActive: true 
        }
      });

      console.log(`Loaded ${suppliers.length} suppliers`);
      dispatch({ type: 'SET_SUPPLIERS', payload: suppliers });
    } catch (error: any) {
      console.error('Error loading suppliers:', error);
      dispatch({ type: 'SET_ERROR', payload: `Failed to load suppliers: ${error.message}` });
      dispatch({ type: 'SET_SUPPLIERS', payload: [] });
    }
  };

  const createSupplier = async (supplierData: Partial<Supplier>): Promise<Supplier> => {
    const db = getDatabaseService();
    const { companyId, locationId } = ensureRequiredData();

    const newSupplier = await db.create('suppliers', {
      ...supplierData,
      companyId,
      locationId,
      isActive: true,
    });

    dispatch({ type: 'ADD_SUPPLIER', payload: newSupplier });
    return newSupplier;
  };

  const updateSupplier = async (supplierId: string, updates: Partial<Supplier>): Promise<Supplier> => {
    const db = getDatabaseService();
    const supplier = await db.findById('suppliers', supplierId);
    if (!supplier) throw new Error('Supplier not found');

    const updatedSupplier = await db.update('suppliers', { ...supplier, ...updates });
    dispatch({ type: 'UPDATE_SUPPLIER', payload: updatedSupplier });
    return updatedSupplier;
  };

  const deleteSupplier = async (supplierId: string): Promise<void> => {
    await updateSupplier(supplierId, { isActive: false });
    dispatch({ type: 'DELETE_SUPPLIER', payload: supplierId });
  };

  // Sales management
  const loadRecentSales = async () => {
    if (!state.currentLocationId || !authState.user?.companyId) {
      console.log('Missing required data for loading sales');
      return;
    }

    try {
      const db = await waitForDatabase();
      
      // First try to get sales with sorting
      let sales: Sale[] = [];
      try {
        sales = await db.find('sales', {
          selector: { 
            companyId: authState.user.companyId,
            locationId: state.currentLocationId
          },
          limit: 10,
          sort: [{ createdAt: 'desc' }]
        });
      } catch (sortError) {
        console.warn('Sorting failed, trying without sort:', sortError);
        // If sorting fails, try without it and sort manually
        const allSales = await db.find('sales', {
          selector: { 
            companyId: authState.user.companyId,
            locationId: state.currentLocationId
          }
        });
        
        // Sort manually and take top 10
        sales = allSales
          .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())
          .slice(0, 10);
      }

      console.log(`Loaded ${sales.length} recent sales`);
      dispatch({ type: 'SET_RECENT_SALES', payload: sales });
    } catch (error: any) {
      console.error('Error loading sales:', error);
      dispatch({ type: 'SET_ERROR', payload: `Failed to load sales: ${error.message}` });
      dispatch({ type: 'SET_RECENT_SALES', payload: [] });
    }
  };

  const createSale = async (saleData: Partial<Sale>): Promise<Sale> => {
    const db = getDatabaseService();
    const { companyId, locationId, userId } = ensureRequiredData();

    const newSale = await db.createSale({
      ...saleData,
      companyId,
      locationId,
      userId,
    });

    dispatch({ type: 'ADD_SALE', payload: newSale });
    
    // Update stock levels
    await loadProducts();
    
    return newSale;
  };

  // Search and filter functions
  const searchProducts = (query: string): Product[] => {
    if (!query.trim()) return state.products;
    
    const searchTerm = query.toLowerCase();
    return state.products.filter(product => 
      product.name.toLowerCase().includes(searchTerm) ||
      product.sku.toLowerCase().includes(searchTerm) ||
      product.brand?.toLowerCase().includes(searchTerm) ||
      product.category.toLowerCase().includes(searchTerm)
    );
  };

  const searchCustomers = (query: string): Customer[] => {
    if (!query.trim()) return state.customers;
    
    const searchTerm = query.toLowerCase();
    return state.customers.filter(customer => 
      customer.name.toLowerCase().includes(searchTerm) ||
      customer.phone.includes(searchTerm) ||
      customer.email?.toLowerCase().includes(searchTerm)
    );
  };

  const getProductsByCategory = (category: string): Product[] => {
    if (category === 'All') return state.products;
    return state.products.filter(product => product.category === category);
  };

  // Dashboard statistics
  const getDashboardStats = async () => {
    try {
      const today = new Date();
      const todayStart = new Date(today.getFullYear(), today.getMonth(), today.getDate());
      
      // Filter today's sales with proper date comparison
      const todaySales = state.recentSales.filter(sale => {
        try {
          const saleDate = new Date(sale.date || sale.createdAt);
          return saleDate >= todayStart;
        } catch (e) {
          console.warn('Invalid sale date:', sale);
          return false;
        }
      });

      const lowStockProducts = state.products.filter(p => 
        p.stock <= (p.minStock || 5)
      );

      const totalInventoryValue = state.products.reduce((sum, p) => 
        sum + ((p.costPrice || p.price) * p.stock), 0
      );

      const creditOutstanding = state.customers.reduce((sum, c) => 
        sum + (c.creditBalance || 0), 0
      );

      return {
        todayRevenue: todaySales.reduce((sum, sale) => sum + (sale.total || 0), 0),
        todayOrders: todaySales.length,
        totalCustomers: state.customers.length,
        lowStockCount: lowStockProducts.length,
        recentSales: state.recentSales.slice(0, 5),
        topProducts: [],
        lowStockProducts: lowStockProducts.slice(0, 5),
        totalProducts: state.products.length,
        totalInventoryValue,
        creditOutstanding
      };
    } catch (error) {
      console.error('Error calculating dashboard stats:', error);
      return {
        todayRevenue: 0,
        todayOrders: 0,
        totalCustomers: 0,
        lowStockCount: 0,
        recentSales: [],
        topProducts: [],
        lowStockProducts: [],
        totalProducts: 0,
        totalInventoryValue: 0,
        creditOutstanding: 0
      };
    }
  };

  return (
    <POSContext.Provider value={{
      state,
      dispatch,
      loadAllData,
      loadAllDataSilently,
      setCurrentLocation,
      createLocation,
      updateLocation,
      deleteLocation,
      getAvailableLocations,
      getCurrentLocation,
      loadProducts,
      createProduct,
      updateProduct,
      deleteProduct,
      loadCategories,
      createCategory,
      updateCategory,
      deleteCategory,
      loadCustomers,
      createCustomer,
      updateCustomer,
      deleteCustomer,
      updateCustomerCredit,
      getCustomerCreditHistory,
      loadSuppliers,
      createSupplier,
      updateSupplier,
      deleteSupplier,
      loadRecentSales,
      createSale,
      searchProducts,
      searchCustomers,
      getProductsByCategory,
      getDashboardStats
    }}>
      {children}
    </POSContext.Provider>
  );
};

export const useApp = () => {
  const context = useContext(POSContext);
  if (context === undefined) {
    throw new Error('useApp must be used within a POSProvider');
  }
  return context;
};