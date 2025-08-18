import React, { createContext, useContext, useReducer, ReactNode } from 'react';
import { AppState, AppAction } from '../types';
import { useAuth } from './AuthContext';

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
    case 'SET_SYNC_STATUS':
      return { ...state, syncStatus: action.payload.status, isSyncing: action.payload.isSyncing, lastSyncTime: action.payload.lastSyncTime || state.lastSyncTime };
    case 'TOGGLE_THEME':
      return { ...state, theme: state.theme === 'light' ? 'dark' : 'light' };
    case 'SET_THEME':
      return { ...state, theme: action.payload };
    case 'TOGGLE_SIDEBAR':
      return { ...state, sidebarCollapsed: !state.sidebarCollapsed };
    case 'SET_PAGINATION':
      return { ...state, currentPage: action.payload.currentPage, totalItems: action.payload.totalItems };
    case 'RESET_STATE':
      return { ...initialState };
    default:
      return state;
  }
};

const MainContext = createContext<any>({ state: initialState, dispatch: () => undefined });

export const MainProvider = ({ children }: { children: ReactNode }) => {
  const { state: authState } = useAuth();
  const [state, dispatch] = useReducer(appReducer, initialState);

  return (
    <MainContext.Provider value={{ state, dispatch }}>
      {children}
    </MainContext.Provider>
  );
};

export const useMain = () => useContext(MainContext);

