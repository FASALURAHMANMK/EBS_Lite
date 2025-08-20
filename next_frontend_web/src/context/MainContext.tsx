import React, { createContext, useContext, useReducer, ReactNode, useEffect } from 'react';
import { AppState, AppAction, Product, Category, Customer, Sale, Supplier } from '../types';
import { products, categories, customers, sales, dashboard, suppliers } from '../services';
import { useAuth } from './AuthContext';
import { setCompanyLocation } from '../services/apiClient';

const initialState: AppState = {
  currentView: 'dashboard',
  selectedCategory: 'All',
  isLoading: false,
  isInitialized: false,
  error: null,
  currentCompanyId: null,
  currentLocationId: null,
  cart: [],
  customer: { phone: '', name: '', creditBalance: 0, address: '' },
  products: [],
  categories: ['All'],
  customers: [],
  suppliers: [],
  recentSales: [],
  theme: 'light',
  sidebarCollapsed: false,
  language: 'en',
  lastSync: null,
  isSyncing: false,
  currentPage: 1,
  itemsPerPage: 20,
  totalItems: 0,
};

const appReducer = (state: AppState, action: AppAction): AppState => {
  switch (action.type) {
    case 'SET_CURRENT_COMPANY':
      return { ...state, currentCompanyId: action.payload };
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
      return { ...state, products: state.products.map(p => p._id === action.payload._id ? action.payload : p) };
    case 'DELETE_PRODUCT':
      return { ...state, products: state.products.filter(p => p._id !== action.payload) };
    case 'SET_CATEGORIES':
      return { ...state, categories: action.payload };
    case 'ADD_CATEGORY':
      return { ...state, categories: [...state.categories, action.payload] };
    case 'SET_CUSTOMERS':
      return { ...state, customers: action.payload };
    case 'ADD_CUSTOMER':
      return { ...state, customers: [...state.customers, action.payload] };
    case 'UPDATE_CUSTOMER':
      return { ...state, customers: state.customers.map(c => c._id === action.payload._id ? action.payload : c) };
    case 'DELETE_CUSTOMER':
      return { ...state, customers: state.customers.filter(c => c._id !== action.payload) };
    case 'SET_SUPPLIERS':
      return { ...state, suppliers: action.payload };
    case 'ADD_SUPPLIER':
      return { ...state, suppliers: [...state.suppliers, action.payload] };
    case 'UPDATE_SUPPLIER':
      return { ...state, suppliers: state.suppliers.map(s => s._id === action.payload._id ? action.payload : s) };
    case 'DELETE_SUPPLIER':
      return { ...state, suppliers: state.suppliers.filter(s => s._id !== action.payload) };
    case 'ADD_TO_CART':
      const existing = state.cart.find(i => i.product._id === action.payload._id);
      if (existing) {
        return {
          ...state,
          cart: state.cart.map(i => i.product._id === action.payload._id ? { ...i, quantity: i.quantity + 1, totalPrice: (i.quantity + 1) * i.unitPrice } : i)
        };
      }
      return {
        ...state,
        cart: [...state.cart, { product: action.payload, quantity: 1, unitPrice: action.payload.price, totalPrice: action.payload.price }]
      };
    case 'REMOVE_FROM_CART':
      return { ...state, cart: state.cart.filter(i => i.product._id !== action.payload) };
    case 'UPDATE_CART_QUANTITY':
      return {
        ...state,
        cart: state.cart.map(i => i.product._id === action.payload.id ? { ...i, quantity: action.payload.quantity, totalPrice: action.payload.quantity * i.unitPrice } : i)
      };
    case 'CLEAR_CART':
      return { ...state, cart: [], customer: { phone: '', name: '', creditBalance: 0, address: '' } };
    case 'SET_CUSTOMER':
      return { ...state, customer: { ...state.customer, ...action.payload } };
    case 'SET_RECENT_SALES':
      return { ...state, recentSales: action.payload };
    case 'ADD_SALE':
      return { ...state, recentSales: [action.payload, ...state.recentSales.slice(0, 9)] };
    case 'TOGGLE_THEME':
      return { ...state, theme: state.theme === 'light' ? 'dark' : 'light' };
    case 'SET_THEME':
      return { ...state, theme: action.payload };
    case 'TOGGLE_SIDEBAR':
      return { ...state, sidebarCollapsed: !state.sidebarCollapsed };
    case 'SET_PAGINATION':
      return { ...state, currentPage: action.payload.currentPage, totalItems: action.payload.totalItems };
    case 'SET_LANGUAGE':
      return { ...state, language: action.payload };
    case 'SET_LAST_SYNC':
      return { ...state, lastSync: action.payload };
    case 'SET_SYNCING':
      return { ...state, isSyncing: action.payload };
    case 'RESET_STATE':
      return { ...initialState };
    default:
      return state;
  }
};

const MainContext = createContext<any>({ state: initialState });

export const MainProvider = ({ children }: { children: ReactNode }) => {
  const [state, dispatch] = useReducer(appReducer, initialState);
  const { state: authState, updateUserLanguages } = useAuth();

  useEffect(() => {
    if (typeof window !== 'undefined') {
      const storedTheme = localStorage.getItem('theme') as 'light' | 'dark' | null;
      const storedLang = localStorage.getItem('language');
      if (storedTheme) {
        dispatch({ type: 'SET_THEME', payload: storedTheme });
      }
      if (storedLang) {
        dispatch({ type: 'SET_LANGUAGE', payload: storedLang });
      } else if (authState.user?.primaryLanguage) {
        dispatch({ type: 'SET_LANGUAGE', payload: authState.user.primaryLanguage });
      }
    }
  }, [authState.user]);

  useEffect(() => {
    if (typeof window !== 'undefined') {
      localStorage.setItem('theme', state.theme);
      localStorage.setItem('language', state.language);
      if (state.theme === 'dark') {
        document.documentElement.classList.add('dark');
      } else {
        document.documentElement.classList.remove('dark');
      }
    }
  }, [state.theme, state.language]);

  useEffect(() => {
    setCompanyLocation(state.currentCompanyId, state.currentLocationId);
  }, [state.currentCompanyId, state.currentLocationId]);

  const loadProducts = async () => {
    try {
      const data = await products.getProducts();
      dispatch({ type: 'SET_PRODUCTS', payload: data });
    } catch (error: any) {
      dispatch({ type: 'SET_ERROR', payload: error.message });
    }
  };

  const loadCategories = async () => {
    try {
      const data = await categories.getCategories();
      dispatch({ type: 'SET_CATEGORIES', payload: ['All', ...data.map((c: Category) => c.name)] });
    } catch (error: any) {
      dispatch({ type: 'SET_ERROR', payload: error.message });
    }
  };

  const loadCustomers = async () => {
    try {
      const data = await customers.getCustomers();
      dispatch({ type: 'SET_CUSTOMERS', payload: data });
    } catch (error: any) {
      dispatch({ type: 'SET_ERROR', payload: error.message });
    }
  };

  const loadSuppliers = async () => {
    try {
      const data = await suppliers.getSuppliers();
      dispatch({ type: 'SET_SUPPLIERS', payload: data });
    } catch (error: any) {
      dispatch({ type: 'SET_ERROR', payload: error.message });
    }
  };


  const loadSales = async () => {
    try {
      const data = await sales.getSales();
      dispatch({ type: 'SET_RECENT_SALES', payload: data });
    } catch (error: any) {
      dispatch({ type: 'SET_ERROR', payload: error.message });
    }
  };

  const loadAllData = async () => {
    dispatch({ type: 'SET_LOADING', payload: true });
    dispatch({ type: 'SET_SYNCING', payload: true });
    try {
      await Promise.all([loadProducts(), loadCategories(), loadCustomers(), loadSuppliers(), loadSales()]);
      dispatch({ type: 'SET_INITIALIZED', payload: true });
      dispatch({ type: 'SET_LAST_SYNC', payload: new Date().toISOString() });
    } catch (error: any) {
      dispatch({ type: 'SET_ERROR', payload: error.message });
    } finally {
      dispatch({ type: 'SET_LOADING', payload: false });
      dispatch({ type: 'SET_SYNCING', payload: false });
    }
  };

  const createProduct = async (payload: Partial<Product>) => {
    try {
      const data = await products.createProduct(payload);
      dispatch({ type: 'ADD_PRODUCT', payload: data });
      return data;
    } catch (error: any) {
      dispatch({ type: 'SET_ERROR', payload: error.message });
      throw error;
    }
  };

  const updateProduct = async (id: string, payload: Partial<Product>) => {
    try {
      const data = await products.updateProduct(id, payload);
      dispatch({ type: 'UPDATE_PRODUCT', payload: data });
      return data;
    } catch (error: any) {
      dispatch({ type: 'SET_ERROR', payload: error.message });
      throw error;
    }
  };

  const deleteProduct = async (id: string) => {
    try {
      await products.deleteProduct(id);
      dispatch({ type: 'DELETE_PRODUCT', payload: id });
    } catch (error: any) {
      dispatch({ type: 'SET_ERROR', payload: error.message });
      throw error;
    }
  };

  const createCategory = async (payload: Partial<Category>) => {
    try {
      const data = await categories.createCategory(payload);
      dispatch({ type: 'ADD_CATEGORY', payload: data.name });
      return data;
    } catch (error: any) {
      dispatch({ type: 'SET_ERROR', payload: error.message });
      throw error;
    }
  };

  const updateCategory = async (id: string, payload: Partial<Category>) => {
    try {
      const data = await categories.updateCategory(id, payload);
      await loadCategories();
      return data;
    } catch (error: any) {
      dispatch({ type: 'SET_ERROR', payload: error.message });
      throw error;
    }
  };

  const deleteCategory = async (id: string) => {
    try {
      await categories.deleteCategory(id);
      await loadCategories();
    } catch (error: any) {
      dispatch({ type: 'SET_ERROR', payload: error.message });
      throw error;
    }
  };

  const createCustomer = async (payload: Partial<Customer>) => {
    try {
      const data = await customers.createCustomer(payload);
      dispatch({ type: 'ADD_CUSTOMER', payload: data });
      return data;
    } catch (error: any) {
      dispatch({ type: 'SET_ERROR', payload: error.message });
      throw error;
    }
  };

  const updateCustomer = async (id: string, payload: Partial<Customer>) => {
    try {
      const data = await customers.updateCustomer(id, payload);
      dispatch({ type: 'UPDATE_CUSTOMER', payload: data });
      return data;
    } catch (error: any) {
      dispatch({ type: 'SET_ERROR', payload: error.message });
      throw error;
    }
  };

  const deleteCustomer = async (id: string) => {
    try {
      await customers.deleteCustomer(id);
      dispatch({ type: 'DELETE_CUSTOMER', payload: id });
    } catch (error: any) {
      dispatch({ type: 'SET_ERROR', payload: error.message });
      throw error;
    }
  };

  const createSupplier = async (payload: Partial<Supplier>) => {
    try {
      const data = await suppliers.createSupplier(payload);
      dispatch({ type: 'ADD_SUPPLIER', payload: data });
      return data;
    } catch (error: any) {
      dispatch({ type: 'SET_ERROR', payload: error.message });
      throw error;
    }
  };

  const updateSupplier = async (id: string, payload: Partial<Supplier>) => {
    try {
      const data = await suppliers.updateSupplier(id, payload);
      dispatch({ type: 'UPDATE_SUPPLIER', payload: data });
      return data;
    } catch (error: any) {
      dispatch({ type: 'SET_ERROR', payload: error.message });
      throw error;
    }
  };

  const deleteSupplier = async (id: string) => {
    try {
      await suppliers.deleteSupplier(id);
      dispatch({ type: 'DELETE_SUPPLIER', payload: id });
    } catch (error: any) {
      dispatch({ type: 'SET_ERROR', payload: error.message });
      throw error;
    }
  };

  const searchSuppliers = (term: string) => {
    return state.suppliers.filter(s =>
      s.name.toLowerCase().includes(term.toLowerCase()) ||
      s.contact.toLowerCase().includes(term.toLowerCase())
    );
  };

  const updateCustomerCredit = async (id: string, amount: number, type: 'credit' | 'debit', description: string) => {
    try {
      const data = await customers.updateCustomerCredit(id, amount, type, description);
      dispatch({ type: 'UPDATE_CUSTOMER', payload: data });
      return data;
    } catch (error: any) {
      dispatch({ type: 'SET_ERROR', payload: error.message });
      throw error;
    }
  };

  const getCustomerCreditHistory = async (id: string) => {
    try {
      const data = await customers.getCustomerCreditHistory(id);
      return data;
    } catch (error: any) {
      dispatch({ type: 'SET_ERROR', payload: error.message });
      throw error;
    }
  };

  const searchProducts = (term: string) => {
    return state.products.filter(p =>
      p.name.toLowerCase().includes(term.toLowerCase()) ||
      p.sku.toLowerCase().includes(term.toLowerCase())
    );
  };

  const searchCustomers = (term: string) => {
    return state.customers.filter(c =>
      c.name.toLowerCase().includes(term.toLowerCase()) ||
      c.phone.includes(term)
    );
  };

  const getProductsByCategory = (categoryName: string) => {
    return state.products.filter(p => p.category === categoryName);
  };

  const createSale = async (payload: Partial<Sale>) => {
    try {
      const data = await sales.createSale(payload);
      dispatch({ type: 'ADD_SALE', payload: data });
      return data;
    } catch (error: any) {
      dispatch({ type: 'SET_ERROR', payload: error.message });
      throw error;
    }
  };

  const setCurrentCompany = async (companyId: string) => {
    dispatch({ type: 'SET_CURRENT_COMPANY', payload: companyId });
    setCompanyLocation(companyId, state.currentLocationId);
    await loadAllData();
  };

  const setCurrentLocation = async (locationId: string) => {
    dispatch({ type: 'SET_CURRENT_LOCATION', payload: locationId });
    setCompanyLocation(state.currentCompanyId, locationId);
    await loadAllData();
  };

  const getDashboardStats = async () => {
    try {
      return await dashboard.getStats();
    } catch (error: any) {
      dispatch({ type: 'SET_ERROR', payload: error.message });
      throw error;
    }
  };

  const setLanguage = (lang: string) => {
    dispatch({ type: 'SET_LANGUAGE', payload: lang });
    updateUserLanguages({ primaryLanguage: lang });
  };

  useEffect(() => {
    loadAllData();
  }, []);

  return (
    <MainContext.Provider
      value={{
        state,
        dispatch,
        loadAllData,
        loadProducts,
        loadCustomers,
    loadSuppliers,
    loadSuppliers,
        loadSuppliers,
        loadSales,
        createProduct,
        updateProduct,
        deleteProduct,
        createCategory,
        updateCategory,
        deleteCategory,
        createCustomer,
        updateCustomer,
        deleteCustomer,
    createSupplier,
    updateSupplier,
    deleteSupplier,
    searchSuppliers,
    createSupplier,
    updateSupplier,
    deleteSupplier,
    searchSuppliers,
    createSupplier,
    updateSupplier,
    deleteSupplier,
    searchSuppliers,
    createSupplier,
    updateSupplier,
    deleteSupplier,
    searchSuppliers,
    createSupplier,
    updateSupplier,
    deleteSupplier,
    searchSuppliers,
    createSupplier,
    updateSupplier,
    deleteSupplier,
    searchSuppliers,
        createSupplier,
        updateSupplier,
        deleteSupplier,
        searchSuppliers,
        updateCustomerCredit,
        getCustomerCreditHistory,
        searchProducts,
        searchCustomers,
        getProductsByCategory,
        createSale,
        setCurrentCompany,
        setCurrentLocation,
        getDashboardStats,
        setLanguage,
      }}
    >
      {children}
    </MainContext.Provider>
  );
};

export const useApp = () => useContext(MainContext);

export const useAppState = <T,>(selector: (state: AppState) => T): T => {
  const { state } = useContext(MainContext);
  return selector(state);
};

export const useAppDispatch = () => useContext(MainContext).dispatch;

export const useAppActions = () => {
  const {
    loadAllData,
    loadProducts,
    loadCustomers,
    loadSuppliers,
    loadSales,
    createProduct,
    updateProduct,
    deleteProduct,
    createCategory,
    updateCategory,
    deleteCategory,
    createCustomer,
    updateCustomer,
    deleteCustomer,
    createSupplier,
    updateSupplier,
    deleteSupplier,
    searchSuppliers,
    updateCustomerCredit,
    getCustomerCreditHistory,
    searchProducts,
    searchCustomers,
    getProductsByCategory,
    createSale,
    setCurrentCompany,
    setCurrentLocation,
    getDashboardStats,
  } = useContext(MainContext);

  return {
    loadAllData,
    loadProducts,
    loadCustomers,
    loadSuppliers,
    loadSales,
    createProduct,
    updateProduct,
    deleteProduct,
    createCategory,
    updateCategory,
    deleteCategory,
    createCustomer,
    updateCustomer,
    deleteCustomer,
    createSupplier,
    updateSupplier,
    deleteSupplier,
    searchSuppliers,
    updateCustomerCredit,
    getCustomerCreditHistory,
    searchProducts,
    searchCustomers,
    getProductsByCategory,
    createSale,
    setCurrentCompany,
    setCurrentLocation,
    getDashboardStats,
  };
};