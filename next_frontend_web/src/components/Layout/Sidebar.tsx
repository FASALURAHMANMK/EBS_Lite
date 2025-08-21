import React, { useState } from 'react';
import { useApp } from '../../context/MainContext';
import { useAuth } from '../../context/AuthContext';
import {
  ShoppingCart,
  BarChart3,
  Package,
  Users,
  Settings,
  ChevronRight,
  ChevronDown,
  Home,
  Truck,
  CreditCard,
  FileText,
  Warehouse,
  UserCheck,
  Shield,
  Info,
  History,
  Undo2,
  Banknote,
  UserRoundCog,
  Building2,
  Eye,
  ArrowDownUp,
  ShoppingBag,
  ListOrdered,
  DollarSign,
  Blocks,
  Printer,
} from 'lucide-react';
import { SidebarView, Product } from '../../types';

interface MenuItem {
  icon?: React.ElementType;
  label: string;
  view?: SidebarView;
  subItems?: MenuItem[];
  badge?: number;
  roles?: string[];
}

const Sidebar: React.FC = () => {
  const { state, dispatch } = useApp();
  const { hasRole } = useAuth();
  const [expandedItems, setExpandedItems] = useState<string[]>(['Sales']);

  const lowStockCount = state.products.filter(
    (p: Product) => typeof p.minStock === 'number' && p.stock <= p.minStock!
  ).length;

  const menuItems: MenuItem[] = [
    {
      icon: Home,
      label: 'Dashboard',
      view: 'dashboard',
      roles: ['Admin', 'Manager', 'Sales', 'Store', 'HR', 'Accountant'],
    },
    {
      icon: ShoppingCart,
      label: 'Sales',
      roles: ['Admin', 'Manager', 'Sales'],
      subItems: [
        { label: 'POS', view: 'sales', icon: ShoppingCart },
        { label: 'Invoice', view: 'sales-invoice', icon: FileText },
        { label: 'Returns', view: 'sales-returns', icon: Undo2 },
        { label: 'Sale History', view: 'sales-history', icon: History },
      ],
    },
    {
      icon: Users,
      label: 'Customers',
      roles: ['Admin', 'Manager', 'Sales'],
      subItems: [
        { label: 'Collections', view: 'collectionss', icon: Banknote },
        { label: 'Customers', view: 'customers', icon: Users },
        { label: 'Customer Management', view: 'customers_management', icon: UserRoundCog },
      ],
    },
    {
      icon: Package,
      label: 'Purchases',
      roles: ['Admin', 'Manager'],
      subItems: [
        { label: 'Purchase Entry', view: 'purchase-entry', icon: ShoppingBag },
        { label: 'Purchase Orders', view: 'purchase-orders', icon: ListOrdered },
        { label: 'Purchase Returns', view: 'purchase-returns', icon: Undo2 },
        { label: 'Suppliers', view: 'suppliers', icon: Truck },
      ],
    },
    {
      icon: Warehouse,
      label: 'Inventory',
      roles: ['Admin', 'Manager', 'Store'],
      subItems: [
        { label: 'Inventory Summary', view: 'inventory', icon: Eye },
        { label: 'Products', view: 'inventory-products', icon: Package },
        {
          label: 'Stock Management',
          icon: Warehouse,
          subItems: [
            { label: 'Stock Transfers', view: 'inventory-stock-transfers', icon: ArrowDownUp },
            { label: 'Low Stock', view: 'inventory-low-stock', icon: Package, badge: lowStockCount },
          ],
        },
        { label: 'Suppliers', view: 'inventory-suppliers', icon: Truck },
      ],
    },
    {
      icon: DollarSign,
      label: 'Accounting',
      roles: ['Admin', 'Manager', 'Accountant'],
      subItems: [
        { label: 'Cash Register', view: 'cash-register', icon: DollarSign },
        { label: 'Vouchers', view: 'vouchers', icon: CreditCard },
        { label: 'Ledgers', view: 'ledgers', icon: FileText },
        { label: 'Banking', view: 'banking', icon: Banknote },
      ],
    },
    {
      icon: BarChart3,
      label: 'Reports',
      roles: ['Admin', 'Manager', 'Accountant'],
      subItems: [
        { label: 'Sales Reports', view: 'sales-reports', icon: BarChart3 },
        { label: 'Inventory Reports', view: 'inventory-reports', icon: Package },
        { label: 'Customer Reports', view: 'customer-reports', icon: Users },
        { label: 'Supplier Reports', view: 'supplier-reports', icon: Truck },
        { label: 'Purchase Reports', view: 'purchase-reports', icon: ShoppingBag },
        { label: 'Accounts Reports', view: 'accounts-reports', icon: DollarSign },
        { label: 'General Reports', view: 'general-reports', icon: FileText },
      ],
    },
    {
      icon: UserCheck,
      label: 'HR',
      roles: ['Admin', 'HR'],
      subItems: [
        { label: 'Employees', view: 'employees', icon: Users },
        { label: 'Attendance', view: 'attendance', icon: History },
        { label: 'Payroll', view: 'payroll', icon: Banknote },
        { label: 'Leave Management', view: 'leave-management', icon: Users },
      ],
    },
    {
      icon: Settings,
      label: 'Settings',
      roles: ['Admin', 'Manager'],
      subItems: [
        { label: 'General', view: 'settings-general', icon: Settings },
        { label: 'Company Settings', view: 'settings-company', icon: Building2 },
        { label: 'Users', view: 'settings-users', icon: UserCheck },
        { label: 'Devices & Networks', view: 'settings-devices', icon: Shield },
        { label: 'Backup & Restore', view: 'settings-backup', icon: History },
        { label: 'Integrations', view: 'settings-integrations', icon: Blocks },
        { label: 'POS & Printer Settings', view: 'settings-pos-printer', icon: Printer },
      ],
    },
  ];

  const toggleExpanded = (label: string) => {
    setExpandedItems(prev =>
      prev.includes(label)
        ? prev.filter(item => item !== label)
        : [...prev, label]
    );
  };

  const handleItemClick = (view: SidebarView) => {
    dispatch({ type: 'SET_VIEW', payload: view });
  };

  const isActive = (view: SidebarView) => state.currentView === view;

  const isItemActive = (item: MenuItem): boolean => {
    if (item.view && isActive(item.view)) return true;
    return item.subItems ? item.subItems.some(isItemActive) : false;
  };

  const renderMenuItems = (items: MenuItem[], depth = 0): React.ReactNode =>
    items.map(item => {
      if (item.roles && !hasRole(item.roles)) return null;
      const active = isItemActive(item);
      const expanded = expandedItems.includes(item.label);
      return (
        <div key={item.label}>
          <button
            onClick={() => {
              if (item.subItems) {
                toggleExpanded(item.label);
              } else if (item.view) {
                handleItemClick(item.view);
              }
            }}
            className={`w-full flex items-center justify-between px-3 py-2.5 rounded-lg text-left transition-colors group ${
              active
                ? 'bg-red-50 dark:bg-red-900/30 text-red-700 dark:text-red-300'
                : 'text-gray-700 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-800'
            }`}
            style={{ paddingLeft: depth * 16 }}
          >
            <div className="flex items-center space-x-3">
              {item.icon && (
                <item.icon
                  className={`w-5 h-5 ${
                    active
                      ? 'text-red-600 dark:text-red-400'
                      : 'text-gray-500 dark:text-gray-400 group-hover:text-gray-700 dark:group-hover:text-gray-200'
                  }`}
                />
              )}
              {!state.sidebarCollapsed && (
                <>
                  <span className="font-medium">{item.label}</span>
                  {typeof item.badge === 'number' && (
                    <span className="ml-2 bg-red-500 text-white text-xs rounded-full px-2 py-0.5">
                      {item.badge}
                    </span>
                  )}
                </>
              )}
            </div>
            {!state.sidebarCollapsed && item.subItems && (
              <div className="ml-auto">
                {expanded ? (
                  <ChevronDown className="w-4 h-4 text-gray-400" />
                ) : (
                  <ChevronRight className="w-4 h-4 text-gray-400" />
                )}
              </div>
            )}
          </button>

          {!state.sidebarCollapsed && item.subItems && expanded && (
            <div className="mt-1 space-y-1">
              {renderMenuItems(item.subItems, depth + 1)}
            </div>
          )}
        </div>
      );
    });

  return (
    <aside className={`${state.sidebarCollapsed ? 'w-16' : 'w-64'} bg-white dark:bg-gray-900 border-r border-gray-200 dark:border-gray-700 flex flex-col transition-all duration-300 shadow-sm`}>
      <div className="flex-1 overflow-y-auto py-4">
        <nav className="space-y-1 px-2">{renderMenuItems(menuItems)}</nav>
      </div>

      {/* About */}
      <div className="border-t border-gray-200 dark:border-gray-700 p-2">
        <div className="text-xs text-gray-500 dark:text-gray-400">
          {state.sidebarCollapsed ? (
            // Collapsed state - show icon and version
            <div className="flex flex-col items-center space-y-1">
              <Info className="w-4 h-4 text-gray-400" />
              <p>v1.1</p>
            </div>
          ) : (
            // Expanded state - show full info
            <>
              <p>Einfach Business Suite Lite</p>
              <p>Version 1.1</p>
              <p>© 2025 Einfach Digital Solutions</p>
            </>
          )}
        </div>
      </div>
    </aside>
  );
};

export default Sidebar;
