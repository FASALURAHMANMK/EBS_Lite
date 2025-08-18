import React from 'react';
import MainLayout from '../components/Layout/MainLayout';
import Dashboard from '../components/ERP/Dashboard';
import CategoryList from '../components/ERP/Common/CategoryList';
import ProductGrid from '../components/ERP/Common/ProductGrid';
import Cart from '../components/ERP/Sales/Cart';
import { useApp } from '../context/MainContext';

const HomePage: React.FC = () => {
  const { state } = useApp();

  const renderCurrentView = () => {
    switch (state.currentView) {
      case 'dashboard':
        return <Dashboard />;
      
      case 'sales':
        return (
          <div className="flex-1 flex overflow-hidden">
            <CategoryList />
            <ProductGrid />
            <Cart />
          </div>
        );
      
      case 'inventory':
        return (
          <div className="flex-1 flex overflow-hidden">
            <CategoryList />
            <ProductGrid />
          </div>
        );
      
      case 'customers':
        return (
          <div className="flex-1 p-6 bg-gray-50 dark:bg-gray-950">
            <div className="bg-white dark:bg-gray-900 rounded-xl p-8 border border-gray-200 dark:border-gray-700">
              <h2 className="text-2xl font-bold text-gray-800 dark:text-white mb-4">Customer Management</h2>
              <p className="text-gray-600 dark:text-gray-400">Customer management features coming soon...</p>
            </div>
          </div>
        );
      
      case 'reports':
        return (
          <div className="flex-1 p-6 bg-gray-50 dark:bg-gray-950">
            <div className="bg-white dark:bg-gray-900 rounded-xl p-8 border border-gray-200 dark:border-gray-700">
              <h2 className="text-2xl font-bold text-gray-800 dark:text-white mb-4">Reports & Analytics</h2>
              <p className="text-gray-600 dark:text-gray-400">Comprehensive reporting features coming soon...</p>
            </div>
          </div>
        );
      
      default:
        return <Dashboard />;
    }
  };

  return (
    <MainLayout>
      <div className="h-full flex flex-col">
        {renderCurrentView()}
      </div>
    </MainLayout>
  );
};

export default HomePage;