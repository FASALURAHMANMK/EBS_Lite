import React, { useState, useEffect } from 'react';
import { useApp } from '../../context/MainContext';
import { useAuth } from '../../context/AuthContext';
import ErrorDisplay from '../Misc/ErrorDisplay';
import { 
  TrendingUp, 
  DollarSign, 
  ShoppingCart, 
  Users, 
  Package,
  AlertTriangle,
  BarChart3,
  CreditCard,
  Zap
} from 'lucide-react';

interface DashboardStats {
  todayRevenue: number;
  todayOrders: number;
  totalCustomers: number;
  lowStockCount: number;
  recentSales: any[];
  topProducts: any[];
  lowStockProducts: any[];
  totalProducts: number;
  totalInventoryValue: number;
  creditOutstanding: number;
}

interface QuickActionButtonProps {
  icon: React.ReactNode;
  label: string;
  onClick: () => void;
  color: string;
  position: number;
  isVisible: boolean;
}

const QuickActionButton: React.FC<QuickActionButtonProps> = ({ 
  icon, 
  label, 
  onClick, 
  color, 
  position, 
  isVisible 
}) => {
  const angle = (position * 45) - 200; 
  const radius = 80; // Distance from center
  const x = Math.cos((angle * Math.PI) / 180) * radius;
  const y = Math.sin((angle * Math.PI) / 180) * radius;

  return (
    <button
      onClick={onClick}
      className={`absolute w-12 h-12 ${color} rounded-full shadow-lg hover:scale-110 transition-all duration-300 ease-in-out flex items-center justify-center group ${
        isVisible ? 'opacity-100 scale-100' : 'opacity-0 scale-0'
      }`}
      style={{
        transform: `translate(${x}px, ${y}px)`,
        transitionDelay: isVisible ? `${position * 50}ms` : '0ms'
      }}
      title={label}
    >
      {icon}
      <span className="absolute bottom-full mb-2 left-1/2 transform -translate-x-1/2 bg-gray-800 dark:bg-gray-700 text-white text-xs px-2 py-1 rounded opacity-0 group-hover:opacity-100 transition-opacity whitespace-nowrap">
        {label}
      </span>
    </button>
  );
};

const Dashboard: React.FC = () => {
  const { state, dispatch, getDashboardStats } = useApp();
  const { state: authState } = useAuth();
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [lastUpdated, setLastUpdated] = useState<Date>(new Date());
  const [isQuickMenuOpen, setIsQuickMenuOpen] = useState(false);

  useEffect(() => {
    loadDashboardData();
    
    // Refresh data every 5 minutes
    const interval = setInterval(loadDashboardData, 5 * 60 * 1000);
    return () => clearInterval(interval);
  }, []);

  const loadDashboardData = async () => {
    try {
      setIsLoading(true);
      const dashboardData = await getDashboardStats();
      
      if (dashboardData) {
        setStats(dashboardData);
      } else {
        // Fallback to calculating stats from current state
        const fallbackStats = calculateFallbackStats();
        setStats(fallbackStats);
      }
      setLastUpdated(new Date());
    } catch (error) {
      console.error('Error loading dashboard data:', error);
      // Use fallback stats on error
      const fallbackStats = calculateFallbackStats();
      setStats(fallbackStats);
    } finally {
      setIsLoading(false);
    }
  };

  const handleRetryData = async () => {
    dispatch({ type: 'SET_ERROR', payload: null });
    window.location.reload(); // Full refresh to reinitialize everything
  };

  const handleClearError = () => {
    dispatch({ type: 'SET_ERROR', payload: null });
  };

  const toggleQuickMenu = () => {
    setIsQuickMenuOpen(!isQuickMenuOpen);
  };

  if (state.error) {
    return (
      <div className="p-6 bg-gray-50 dark:bg-gray-950 min-h-full">
        <div className="mb-6">
          <h1 className="text-3xl font-bold text-gray-800 dark:text-white mb-2">Dashboard</h1>
          <p className="text-gray-600 dark:text-gray-400">
            Welcome back, {authState.user?.fullName}! 
          </p>
        </div>
        
        <ErrorDisplay 
          error={state.error}
          onRetry={handleRetryData}
          onClearError={handleClearError}
        />
        
        {/* Show basic stats even with errors if we have some data */}
        {(state.products.length > 0 || state.customers.length > 0) && (
          <div className="mt-6">
            <h2 className="text-lg font-semibold text-gray-800 dark:text-white mb-4">
              Available Data (Limited)
            </h2>
            <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
              <div className="bg-white dark:bg-gray-900 rounded-xl p-6 border border-gray-200 dark:border-gray-700">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm text-gray-600 dark:text-gray-400 mb-1">Products</p>
                    <p className="text-2xl font-bold text-gray-800 dark:text-white">{state.products.length}</p>
                  </div>
                </div>
              </div>
              <div className="bg-white dark:bg-gray-900 rounded-xl p-6 border border-gray-200 dark:border-gray-700">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm text-gray-600 dark:text-gray-400 mb-1">Customers</p>
                    <p className="text-2xl font-bold text-gray-800 dark:text-white">{state.customers.length}</p>
                  </div>
                </div>
              </div>
              <div className="bg-white dark:bg-gray-900 rounded-xl p-6 border border-gray-200 dark:border-gray-700">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm text-gray-600 dark:text-gray-400 mb-1">Categories</p>
                    <p className="text-2xl font-bold text-gray-800 dark:text-white">{state.categories.length - 1}</p>
                  </div>
                </div>
              </div>
              <div className="bg-white dark:bg-gray-900 rounded-xl p-6 border border-gray-200 dark:border-gray-700">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm text-gray-600 dark:text-gray-400 mb-1">Recent Sales</p>
                    <p className="text-2xl font-bold text-gray-800 dark:text-white">{state.recentSales.length}</p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}
      </div>
    );
  }

  const calculateFallbackStats = (): DashboardStats => {
    const today = new Date();
    const todayStart = new Date(today.getFullYear(), today.getMonth(), today.getDate());
    
    // Filter today's sales
    const todaySales = state.recentSales.filter(sale => 
      new Date(sale.date) >= todayStart
    );
  
    // Calculate low stock products
    const lowStockProducts = state.products.filter(p => 
      p.stock <= (p.minStock || 5)
    );
  
    // Calculate total inventory value
    const totalInventoryValue = state.products.reduce((sum, p) => 
      sum + (p.price * p.stock), 0
    );
  
    // Calculate credit outstanding
    const creditOutstanding = state.customers.reduce((sum, c) => 
      sum + c.creditBalance, 0
    );
  
    // Calculate top products (simplified)
    const productSales = new Map();
    state.recentSales.forEach(sale => {
      sale.items.forEach((item: any) => {
        const current = productSales.get(item.productId) || { name: item.productName, quantity: 0, revenue: 0 };
        current.quantity += item.quantity;
        current.revenue += item.totalPrice;
        productSales.set(item.productId, current);
      });
    });
    
    const topProducts = Array.from(productSales.values())
      .sort((a, b) => b.revenue - a.revenue)
      .slice(0, 5);
  
    return {
      todayRevenue: todaySales.reduce((sum, sale) => sum + sale.total, 0),
      todayOrders: todaySales.length,
      totalCustomers: state.customers.length,
      lowStockCount: lowStockProducts.length,
      recentSales: state.recentSales.slice(0, 5),
      topProducts,
      lowStockProducts: lowStockProducts.slice(0, 5),
      totalProducts: state.products.length,
      totalInventoryValue,
      creditOutstanding
    };
  };

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD'
    }).format(amount);
  };

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  const getStockStatusColor = (product: any) => {
    if (product.stock === 0) return 'text-red-600 dark:text-red-400';
    if (product.stock <= (product.minStock || 5)) return 'text-yellow-600 dark:text-yellow-400';
    return 'text-green-600 dark:text-green-400';
  };

  if (isLoading && !stats) {
    return (
      <div className="p-6 bg-gray-50 dark:bg-gray-950 min-h-full">
        <div className="flex items-center justify-center h-64">
          <div className="text-center">
            <div className="w-8 h-8 border-4 border-red-500 border-t-transparent rounded-full animate-spin mx-auto mb-4"></div>
            <p className="text-gray-600 dark:text-gray-400">Loading dashboard...</p>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="p-6 bg-gray-50 dark:bg-gray-950 min-h-full relative">
      {/* Header */}
      <div className="mb-8">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-bold text-gray-800 dark:text-white mb-2">Dashboard</h1>
            <p className="text-gray-600 dark:text-gray-400">
              Welcome back, {authState.user?.fullName}! Here's how your business is doing today.
            </p>
          </div>
        </div>
      </div>

      {/* Key Metrics */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        <div className="bg-white dark:bg-gray-900 rounded-xl p-6 border border-gray-200 dark:border-gray-700 shadow-sm">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600 dark:text-gray-400 mb-1">Today's Revenue</p>
              <p className="text-2xl font-bold text-gray-800 dark:text-white">
                {formatCurrency(stats?.todayRevenue || 0)}
              </p>
              <div className="flex items-center mt-2">
                <TrendingUp className="w-4 h-4 text-green-500 mr-1" />
                <span className="text-sm text-green-600 dark:text-green-400">
                  {stats?.todayOrders || 0} orders
                </span>
              </div>
            </div>
            <div className="bg-gradient-to-r from-green-500 to-green-600 p-3 rounded-lg">
              <DollarSign className="w-6 h-6 text-white" />
            </div>
          </div>
        </div>

        <div className="bg-white dark:bg-gray-900 rounded-xl p-6 border border-gray-200 dark:border-gray-700 shadow-sm">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600 dark:text-gray-400 mb-1">Total Products</p>
              <p className="text-2xl font-bold text-gray-800 dark:text-white">
                {stats?.totalProducts || 0}
              </p>
              <div className="flex items-center mt-2">
                <Package className="w-4 h-4 text-blue-500 mr-1" />
                <span className="text-sm text-blue-600 dark:text-blue-400">
                  {formatCurrency(stats?.totalInventoryValue || 0)} value
                </span>
              </div>
            </div>
            <div className="bg-gradient-to-r from-blue-500 to-blue-600 p-3 rounded-lg">
              <Package className="w-6 h-6 text-white" />
            </div>
          </div>
        </div>

        <div className="bg-white dark:bg-gray-900 rounded-xl p-6 border border-gray-200 dark:border-gray-700 shadow-sm">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600 dark:text-gray-400 mb-1">Total Customers</p>
              <p className="text-2xl font-bold text-gray-800 dark:text-white">
                {stats?.totalCustomers || 0}
              </p>
              <div className="flex items-center mt-2">
                <CreditCard className="w-4 h-4 text-purple-500 mr-1" />
                <span className="text-sm text-purple-600 dark:text-purple-400">
                  {formatCurrency(stats?.creditOutstanding || 0)} credit
                </span>
              </div>
            </div>
            <div className="bg-gradient-to-r from-purple-500 to-purple-600 p-3 rounded-lg">
              <Users className="w-6 h-6 text-white" />
            </div>
          </div>
        </div>

        <div className="bg-white dark:bg-gray-900 rounded-xl p-6 border border-gray-200 dark:border-gray-700 shadow-sm">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600 dark:text-gray-400 mb-1">Low Stock Items</p>
              <p className="text-2xl font-bold text-gray-800 dark:text-white">
                {stats?.lowStockCount || 0}
              </p>
              <div className="flex items-center mt-2">
                <AlertTriangle className="w-4 h-4 text-yellow-500 mr-1" />
                <span className="text-sm text-yellow-600 dark:text-yellow-400">
                  Needs attention
                </span>
              </div>
            </div>
            <div className="bg-gradient-to-r from-yellow-500 to-yellow-600 p-3 rounded-lg">
              <AlertTriangle className="w-6 h-6 text-white" />
            </div>
          </div>
        </div>
      </div>

      {/* Charts and Lists */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        {/* Recent Sales */}
        <div className="lg:col-span-2">
          <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 shadow-sm">
            <div className="p-6 border-b border-gray-200 dark:border-gray-700">
              <div className="flex items-center justify-between">
                <h3 className="text-lg font-semibold text-gray-800 dark:text-white">Recent Sales</h3>
                <button className="text-red-600 hover:text-red-800 dark:text-red-400 dark:hover:text-red-300 text-sm font-medium">
                  View All
                </button>
              </div>
            </div>
            <div className="p-6">
            {stats?.recentSales && stats.recentSales.length > 0 ? (
  <div className="space-y-4">
    {stats.recentSales.map((sale, index) => (
      <div key={sale._id || index} className="flex items-center justify-between p-4 bg-gray-50 dark:bg-gray-800 rounded-lg">
        <div className="flex items-center space-x-4">
          <div className="w-10 h-10 bg-red-100 dark:bg-red-900/30 rounded-full flex items-center justify-center">
            <ShoppingCart className="w-5 h-5 text-red-600 dark:text-red-400" />
          </div>
          <div>
            <p className="text-sm font-medium text-gray-800 dark:text-white">
              Sale #{sale.saleNumber || `SAL-${index + 1}`}
            </p>
            <p className="text-xs text-gray-500 dark:text-gray-400">
              {sale.items?.length || 0} items • {formatDate(sale.date)}
            </p>
            {sale.customerId && (
              <p className="text-xs text-gray-500 dark:text-gray-400">
                Customer sale
              </p>
            )}
          </div>
        </div>
        <div className="text-right">
          <p className="text-sm font-semibold text-gray-800 dark:text-white">
            {formatCurrency(sale.total)}
          </p>
          <p className={`text-xs ${
            sale.paymentStatus === 'paid' ? 'text-green-600 dark:text-green-400' :
            sale.paymentStatus === 'pending' ? 'text-yellow-600 dark:text-yellow-400' :
            'text-gray-500 dark:text-gray-400'
          }`}>
            {sale.paymentMethod} • {sale.paymentStatus}
          </p>
        </div>
      </div>
    ))}
  </div>
) : (
  <div className="text-center py-8">
    <ShoppingCart className="w-12 h-12 text-gray-400 mx-auto mb-4" />
    <p className="text-gray-500 dark:text-gray-400">No sales yet today</p>
    <p className="text-sm text-gray-400 dark:text-gray-500">Start making sales to see them here</p>
  </div>
)}
            </div>
          </div>
        </div>

        {/* Sidebar Widgets */}
        <div className="space-y-6">
          {/* Top Products */}
          <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 shadow-sm">
            <div className="p-6 border-b border-gray-200 dark:border-gray-700">
              <h3 className="text-lg font-semibold text-gray-800 dark:text-white">Top Products</h3>
            </div>
            <div className="p-6">
              {stats?.topProducts && stats.topProducts.length > 0 ? (
                <div className="space-y-3">
                  {stats.topProducts.map((product, index) => (
                    <div key={index} className="flex items-center justify-between">
                      <div className="flex items-center space-x-3">
                        <div className="w-8 h-8 bg-gray-100 dark:bg-gray-800 rounded-lg flex items-center justify-center">
                          <span className="text-sm font-medium text-gray-600 dark:text-gray-400">
                            #{index + 1}
                          </span>
                        </div>
                        <div>
                          <p className="text-sm font-medium text-gray-800 dark:text-white line-clamp-1">
                            {product.name}
                          </p>
                          <p className="text-xs text-gray-500 dark:text-gray-400">
                            {product.quantity} sold
                          </p>
                        </div>
                      </div>
                      <p className="text-sm font-semibold text-gray-800 dark:text-white">
                        {formatCurrency(product.revenue)}
                      </p>
                    </div>
                  ))}
                </div>
              ) : (
                <div className="text-center py-6">
                  <BarChart3 className="w-8 h-8 text-gray-400 mx-auto mb-2" />
                  <p className="text-sm text-gray-500 dark:text-gray-400">No sales data yet</p>
                </div>
              )}
            </div>
          </div>

          {/* Low Stock Alert */}
          <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 shadow-sm">
            <div className="p-6 border-b border-gray-200 dark:border-gray-700">
              <h3 className="text-lg font-semibold text-gray-800 dark:text-white flex items-center">
                <AlertTriangle className="w-5 h-5 text-yellow-500 mr-2" />
                Low Stock Alert
              </h3>
            </div>
            <div className="p-6">
            {stats?.lowStockProducts && stats.lowStockProducts.length > 0 ? (
  <div className="space-y-3">
    {stats.lowStockProducts.map((product, index) => (
      <div key={product._id || index} className="flex items-center justify-between">
        <div>
          <p className="text-sm font-medium text-gray-800 dark:text-white line-clamp-1">
            {product.name}
          </p>
          <p className="text-xs text-gray-500 dark:text-gray-400">
            {product.sku}
          </p>
        </div>
        <div className="text-right">
          <p className={`text-sm font-semibold ${getStockStatusColor(product)}`}>
            {product.stock} left
          </p>
          <p className="text-xs text-gray-500 dark:text-gray-400">
            Min: {product.minStock || 5}
          </p>
        </div>
      </div>
    ))}
  </div>
) : (
  <div className="text-center py-6">
    <Package className="w-8 h-8 text-green-400 mx-auto mb-2" />
    <p className="text-sm text-green-600 dark:text-green-400">All products in stock!</p>
  </div>
)}
            </div>
          </div>
        </div>
      </div>

      {/* Floating Quick Actions Button */}
      <div className="fixed bottom-8 right-8 z-50">
        <div className="relative">
          {/* Action Buttons - Half Circle */}
          <QuickActionButton
            icon={<ShoppingCart className="w-5 h-5 text-white" />}
            label="New Sale"
            onClick={() => dispatch({ type: 'SET_VIEW', payload: 'sales' })}
            color="bg-gradient-to-r from-red-500 to-red-600"
            position={0}
            isVisible={isQuickMenuOpen}
          />
          
          <QuickActionButton
            icon={<Package className="w-5 h-5 text-white" />}
            label="Products"
            onClick={() => dispatch({ type: 'SET_VIEW', payload: 'inventory' })}
            color="bg-gradient-to-r from-blue-500 to-blue-600"
            position={1}
            isVisible={isQuickMenuOpen}
          />
          
          <QuickActionButton
            icon={<Users className="w-5 h-5 text-white" />}
            label="Customers"
            onClick={() => dispatch({ type: 'SET_VIEW', payload: 'customers' })}
            color="bg-gradient-to-r from-green-500 to-green-600"
            position={2}
            isVisible={isQuickMenuOpen}
          />
          
          <QuickActionButton
            icon={<BarChart3 className="w-5 h-5 text-white" />}
            label="Reports"
            onClick={() => dispatch({ type: 'SET_VIEW', payload: 'reports' })}
            color="bg-gradient-to-r from-purple-500 to-purple-600"
            position={3}
            isVisible={isQuickMenuOpen}
          />

          {/* Main FAB Button */}
          <button
            onClick={toggleQuickMenu}
            className={`w-16 h-16 bg-gradient-to-r from-orange-500 to-red-500 hover:from-orange-600 hover:to-red-600 rounded-full shadow-2xl flex items-center justify-center transition-all duration-300 ease-in-out transform hover:scale-110 ${
              isQuickMenuOpen ? 'rotate-45' : 'rotate-0'
            }`}
          >
            <Zap className="w-8 h-8 text-white" />
          </button>
          
          {/* Backdrop overlay when menu is open */}
          {isQuickMenuOpen && (
            <div 
              className="fixed inset-0 bg-black/20 -z-10"
              onClick={() => setIsQuickMenuOpen(false)}
            />
          )}
        </div>
      </div>
    </div>
  );
};

export default Dashboard;