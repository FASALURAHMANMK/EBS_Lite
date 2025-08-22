export interface User {
  _id: string;
  username: string;
  email: string;
  fullName: string;
  role: 'Admin' | 'Manager' | 'Sales' | 'HR' | 'Accountant' | 'Store' | 'User';
  companyId: string;
  isActive: boolean;
  permissions: string[];
  primaryLanguage?: string;
  secondaryLanguage?: string;
  createdAt: string;
  updatedAt: string;
}

export interface Location {
  _id: string;
  name: string;
  address: string;
  phone?: string;
  email?: string;
  code: string; // Unique location code
  isActive: boolean;
  companyId: string;
  settings?: {
    timezone?: string;
    currency?: string;
  };
  createdAt: string;
  updatedAt: string;
}

export interface Company {
  _id: string;
  name: string;
  code: string;
  address: string;
  phone: string;
  email: string;
  taxNumber?: string;
  website?: string;
  logo?: string;
  isActive: boolean;
  locations: Location[];
  settings: {
    currency: string;
    timezone: string;
    dateFormat: string;
    theme: 'light' | 'dark';
  };
  createdAt: string;
  updatedAt: string;
}

export interface AuditFields {
  createdBy: string;
  updatedBy?: string;
  createdAt: string;
  updatedAt: string;
}

export interface ProductAttributeDefinition {
  attributeId: string;
  name: string;
  type: 'TEXT' | 'NUMBER' | 'DATE' | 'BOOLEAN' | 'SELECT';
  isRequired: boolean;
  options?: string[];
}

export interface ProductAttributeValue {
  attributeId: string;
  value: string;
  definition?: ProductAttributeDefinition;
}

export interface ProductBarcode {
  barcodeId?: string;
  productId?: string;
  barcode: string;
  packSize: number;
  costPrice?: number;
  sellingPrice?: number;
  isPrimary: boolean;
}

export interface ProductStockLevel {
  locationId: string;
  quantity: number;
}

export interface Product extends AuditFields {
  _id: string;
  name: string;
  price: number;
  stock: number;
  category: string;
  brand?: string;
  model?: string;
  sku: string;
  supplierId?: string;
  image?: string;
  description?: string;
  warranty?: string;
  specifications?: Record<string, string>;
  companyId: string;
  locationId: string;
  isActive: boolean;
  costPrice?: number;
  minStock?: number;
  maxStock?: number;
  barcodes?: ProductBarcode[];
  attributes?: ProductAttributeValue[];
  stockLevels?: ProductStockLevel[];
}

export interface Category extends AuditFields {
  _id: string;
  name: string;
  description?: string;
  companyId: string;
  locationId: string;
  isActive: boolean;
}

export interface Customer extends AuditFields {
  _id: string;
  name: string;
  phone: string;
  email?: string;
  address?: string;
  credit_balance: number;
  creditLimit: number;
  loyaltyPoints?: number;
  companyId: string;
  locationId: string;
  isActive: boolean;
  notes?: string;
}

export interface CreditTransaction extends AuditFields {
  _id: string;
  customerId: string;
  amount: number;
  type: 'credit' | 'debit';
  description: string;
  date: string;
  newBalance: number;
  companyId: string;
  locationId: string;
  userId: string;
}

export interface CartItem {
  product: Product;
  quantity: number;
  unitPrice: number;
  totalPrice: number;
  discount?: number;
}

export interface Sale extends AuditFields {
  _id: string;
  saleNumber: string;
  customerId?: string;
  items: Array<{
    productId: string;
    productName: string;
    quantity: number;
    unitPrice: number;
    totalPrice: number;
    discount?: number;
  }>;
  subtotal: number;
  discount: number;
  tax: number;
  total: number;
  paymentMethod: 'cash' | 'card' | 'upi' | 'netbanking' | 'credit';
  paymentStatus: 'paid' | 'pending' | 'partial';
  notes?: string;
  companyId: string;
  locationId: string;
  userId: string;
  date: string;
}

export interface Supplier extends AuditFields {
  _id: string;
  name: string;
  contact: string;
  email?: string;
  address?: string;
  companyId: string;
  locationId: string;
  isActive: boolean;
  notes?: string;
}

export interface Role extends AuditFields {
  _id: string;
  name: string;
  permissions: string[];
  companyId: string;
}

export interface Employee extends AuditFields {
  _id: string;
  name: string;
  phone?: string;
  email?: string;
  position?: string;
  department?: string;
  companyId: string;
  locationId?: string;
  isActive: boolean;
}

export interface AttendanceRecord extends AuditFields {
  _id: string;
  employeeId: string;
  type: 'check-in' | 'check-out' | 'leave';
  timestamp: string;
  note?: string;
}

export type SidebarView =
  | 'dashboard'
  | 'sales'
  | 'sales-invoice'
  | 'sales-returns'
  | 'sales-history'
  | 'collectionss'
  | 'customers'
  | 'customers_management'
  | 'purchase-entry'
  | 'purchase-orders'
  | 'purchase-returns'
  | 'suppliers'
  | 'inventory'
  | 'inventory-products'
  | 'inventory-stock-transfers'
  | 'inventory-low-stock'
  | 'inventory-suppliers'
  | 'cash-register'
  | 'vouchers'
  | 'ledgers'
  | 'banking'
  | 'sales-reports'
  | 'inventory-reports'
  | 'customer-reports'
  | 'supplier-reports'
  | 'purchase-reports'
  | 'accounts-reports'
  | 'general-reports'
  | 'employees'
  | 'attendance'
  | 'payroll'
  | 'leave-management'
  | 'settings-general'
  | 'settings-company'
  | 'settings-users'
  | 'settings-devices'
  | 'settings-backup'
  | 'settings-integrations'
  | 'settings-pos-printer';

export interface AppState {
  // UI State
  currentView: SidebarView;
  selectedCategory: string;
  isLoading: boolean;
  isInitialized: boolean;
  error: string | null;
  currentCompanyId: string | null;
  currentLocationId: string | null;
  
  // Cart State
  cart: CartItem[];
  customer: {
    _id?: string;
    name: string;
    phone: string;
    address?: string;
    credit_balance?: number;
    creditLimit?: number;
  };
  
  // Data State
  products: Product[];
  categories: string[];
  customers: Customer[];
  suppliers: Supplier[];
  recentSales: Sale[];

  // UI Preferences
  theme: 'light' | 'dark';
  sidebarCollapsed: boolean;
  language: string;

  // Sync Status
  lastSync: string | null;
  isSyncing: boolean;
  unsyncedSales: Partial<Sale>[];

  // Pagination
  currentPage: number;
  itemsPerPage: number;
  totalItems: number;
}

// Dashboard Types
export interface DashboardStats {
  todayRevenue: number;
  todayOrders: number;
  totalCustomers: number;
  lowStockCount: number;
  recentSales: Sale[];
  topProducts: TopProduct[];
  lowStockProducts: Product[];
  totalProducts: number;
  totalInventoryValue: number;
  creditOutstanding: number;
}

export interface QuickActionCounts {
  salesToday: number;
  purchasesToday: number;
  collectionsToday: number;
  paymentsToday: number;
  receiptsToday: number;
  journalsToday: number;
  lowStockItems: number;
}

export interface TopProduct {
  name: string;
  quantity: number;
  revenue: number;
}

// Report Types
export interface SalesReport {
  period: string;
  totalSales: number;
  totalRevenue: number;
  averageOrderValue: number;
  topProducts: TopProduct[];
  salesByPaymentMethod: Record<string, number>;
  salesByCategory: Record<string, number>;
}

export interface InventoryReport {
  totalProducts: number;
  totalValue: number;
  lowStockItems: number;
  outOfStockItems: number;
  topValueProducts: Product[];
  categoryBreakdown: Record<string, number>;
}

export interface CustomerReport {
  totalCustomers: number;
  activeCustomers: number;
  totalCreditOutstanding: number;
  averageCreditBalance: number;
  topCustomersBySales: CustomerSalesSummary[];
  newCustomersThisMonth: number;
}

export interface CustomerSalesSummary {
  customerId: string;
  customerName: string;
  totalPurchases: number;
  totalSpent: number;
  lastPurchaseDate: string;
}

// Settings Types
export interface GeneralSettings {
  companyName: string;
  companyAddress: string;
  companyPhone: string;
  companyEmail: string;
  currency: string;
  timezone: string;
  dateFormat: string;
  taxRate: number;
  receiptMessage?: string;
}

export interface UserSettings {
  theme: 'light' | 'dark';
  language: string;
  notifications: {
    lowStock: boolean;
    newSales: boolean;
    customerPayments: boolean;
  };
}

// API Response Types
export interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: string;
  message?: string;
}

export interface PaginatedResponse<T> {
  data: T[];
  totalItems: number;
  currentPage: number;
  totalPages: number;
  hasNextPage: boolean;
  hasPreviousPage: boolean;
}

// Form Types
export interface ProductFormData {
  name: string;
  price: number;
  costPrice: number;
  stock: number;
  category: string;
  brand: string;
  model: string;
  sku: string;
  supplierId: string;
  barcodes: ProductBarcode[];
  attributes: Record<string, string>;
  description: string;
  warranty: string;
  minStock: number;
  maxStock: number;
  specifications: Record<string, string>;
  companyId: string;
  locationId: string;
}

export interface CustomerFormData {
  name: string;
  phone: string;
  email: string;
  address: string;
  creditLimit: number;
  notes: string;
  companyId: string;
  locationId: string;
}

export interface SupplierFormData {
  name: string;
  contact: string;
  email: string;
  address: string;
  notes: string;
  companyId: string;
  locationId: string;
}

export interface CategoryFormData {
  name: string;
  description: string;
  companyId: string;
  locationId: string;
}
// Utility Types
export type EntityId = string;
export type Timestamp = string;
export type Currency = number;

// Action Types for Reducers
type AppAction =
  | { type: 'SET_CURRENT_COMPANY'; payload: string }
  | { type: 'SET_CURRENT_LOCATION'; payload: string }
  | { type: 'LOAD_ALL_DATA' }
  | { type: 'SET_LOADING'; payload: boolean }
  | { type: 'SET_INITIALIZED'; payload: boolean }
  | { type: 'SET_ERROR'; payload: string | null }
  | { type: 'SET_VIEW'; payload: SidebarView }
  | { type: 'SET_CATEGORY'; payload: string }
  | { type: 'SET_PRODUCTS'; payload: Product[] }
  | { type: 'ADD_PRODUCT'; payload: Product }
  | { type: 'UPDATE_PRODUCT'; payload: Product }
  | { type: 'DELETE_PRODUCT'; payload: string }
  | { type: 'SET_CATEGORIES'; payload: string[] }
  | { type: 'ADD_CATEGORY'; payload: string }
  | { type: 'SET_CUSTOMERS'; payload: Customer[] }
  | { type: 'ADD_CUSTOMER'; payload: Customer }
  | { type: 'UPDATE_CUSTOMER'; payload: Customer }
  | { type: 'DELETE_CUSTOMER'; payload: string }
  | { type: 'SET_SUPPLIERS'; payload: Supplier[] }
  | { type: 'ADD_SUPPLIER'; payload: Supplier }
  | { type: 'UPDATE_SUPPLIER'; payload: Supplier }
  | { type: 'DELETE_SUPPLIER'; payload: string }
  | { type: 'ADD_TO_CART'; payload: Product }
  | { type: 'REMOVE_FROM_CART'; payload: string }
  | { type: 'UPDATE_CART_QUANTITY'; payload: { id: string; quantity: number } }
  | { type: 'CLEAR_CART' }
  | { type: 'SET_CUSTOMER'; payload: Partial<AppState['customer']> }
  | { type: 'SET_RECENT_SALES'; payload: Sale[] }
  | { type: 'ADD_SALE'; payload: Sale }
  | { type: 'TOGGLE_THEME' }
  | { type: 'SET_THEME'; payload: 'light' | 'dark' }
  | { type: 'TOGGLE_SIDEBAR' }
  | { type: 'SET_PAGINATION'; payload: { currentPage: number; totalItems: number } }
  | { type: 'SET_LANGUAGE'; payload: string }
  | { type: 'SET_LAST_SYNC'; payload: string | null }
  | { type: 'SET_SYNCING'; payload: boolean }
  | { type: 'SET_UNSYNCED_SALES'; payload: Partial<Sale>[] }
  | { type: 'QUEUE_SALE'; payload: Partial<Sale> }
  | { type: 'RESET_STATE' };

type AuthAction =
  | { type: 'AUTH_INIT_START' }
  | { type: 'AUTH_INIT_COMPLETE' }
  | { type: 'LOGIN_START' }
  | { type: 'LOGIN_SUCCESS'; payload: { user: User; company: Company } }
  | { type: 'LOGIN_FAILURE'; payload: string }
  | { type: 'LOGOUT' }
  | { type: 'REGISTER_START' }
  | { type: 'REGISTER_SUCCESS' }
  | { type: 'REGISTER_FAILURE'; payload: string }
  | { type: 'CLEAR_ERROR' }
  | { type: 'UPDATE_USER_LANGUAGES'; payload: { primaryLanguage: string; secondaryLanguage?: string } };

  export interface AuthState {
    isAuthenticated: boolean;
    user: User | null;
    company: Company | null;
    loading: boolean;
    error: string | null;
    isInitialized: boolean;
  }

export type {
  User as UserType,
  Company as CompanyType,
  Product as ProductType,
  Category as CategoryType,
  Customer as CustomerType,
  Sale as SaleType,
  Supplier as SupplierType,
  AuthAction, AppAction
};