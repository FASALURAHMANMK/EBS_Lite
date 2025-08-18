import React from 'react';
import { useApp } from '../context/MainContext';
import { useAuth } from '../context/AuthContext';
import MainLayout from './Layout/MainLayout';
import Dashboard from './ERP/Dashboard';
import SalesInterface from './ERP/Sales/SalesInterface';
import ProductManagement from './ERP/Inventory/ProductManagement';
import CustomerManagement from './ERP/Customers/CustomerManagement';
import ErrorBoundary from './Misc/ErrorBoundary';
import { MapPin } from 'lucide-react';

// Database Loading Screen Component (inline for now)
const DatabaseLoadingScreen: React.FC<{
  isAuthenticated: boolean;
  databaseReady: boolean;
  user?: { fullName?: string } | null;
}> = ({ isAuthenticated, databaseReady, user }) => {
  const getStatus = () => {
    if (isAuthenticated && databaseReady) {
      return {
        title: 'Ready!',
        message: 'Database initialized successfully',
        color: 'text-green-600 dark:text-green-400'
      };
    } else if (isAuthenticated && !databaseReady) {
      return {
        title: 'Initializing Database...',
        message: 'Setting up your workspace',
        color: 'text-blue-600 dark:text-blue-400'
      };
    } else {
      return {
        title: 'Loading...',
        message: 'Preparing application',
        color: 'text-gray-600 dark:text-gray-400'
      };
    }
  };

  const status = getStatus();

  return (
    <div className="min-h-screen bg-gradient-to-br from-red-50 to-red-100 dark:from-gray-900 dark:to-gray-800 flex items-center justify-center">
      <div className="text-center p-8">
        {/* Logo */}
        <div className="w-16 h-16 bg-gradient-to-r from-red-500 to-red-600 rounded-2xl flex items-center justify-center mx-auto mb-6 shadow-lg">
          <span className="text-white font-bold text-xl">iQ</span>
        </div>
        
        {/* App Title */}
        <h1 className="text-2xl font-bold text-gray-800 dark:text-white mb-2">
          IQ Spare
        </h1>
        <p className="text-gray-600 dark:text-gray-400 mb-8">
          Electronics & Telecom
        </p>

        {/* Status */}
        <div className="mb-6">
          <div className={`font-medium ${status.color} text-lg mb-2`}>
            {status.title}
          </div>
          <div className="text-sm text-gray-600 dark:text-gray-400">
            {status.message}
          </div>
        </div>

        {/* Loading Spinner */}
        {!databaseReady && (
          <div className="w-8 h-8 border-4 border-red-500 border-t-transparent rounded-full animate-spin mx-auto mb-4"></div>
        )}

        {/* User Welcome */}
        {user?.fullName && (
          <p className="text-gray-600 dark:text-gray-400 mb-4">
            Welcome back, {user.fullName}!
          </p>
        )}

        {/* Progress Steps */}
        <div className="flex items-center justify-center space-x-4 mb-8">
          <div className="flex items-center space-x-2">
            <div className={`w-3 h-3 rounded-full ${
              isAuthenticated ? 'bg-green-500' : 'bg-gray-300 dark:bg-gray-600'
            }`}></div>
            <span className="text-sm text-gray-600 dark:text-gray-400">
              Authentication
            </span>
          </div>
          
          <div className="w-8 h-0.5 bg-gray-300 dark:bg-gray-600"></div>
          
          <div className="flex items-center space-x-2">
            <div className={`w-3 h-3 rounded-full ${
              databaseReady ? 'bg-green-500' : 
              isAuthenticated ? 'bg-blue-500 animate-pulse' : 'bg-gray-300 dark:bg-gray-600'
            }`}></div>
            <span className="text-sm text-gray-600 dark:text-gray-400">
              Database
            </span>
          </div>
        </div>

        {/* Loading Tips */}
        <div className="max-w-md mx-auto">
          <div className="text-sm text-gray-500 dark:text-gray-500">
            {!isAuthenticated && "Authenticating user..."}
            {isAuthenticated && !databaseReady && "Initializing database and syncing data..."}
            {isAuthenticated && databaseReady && "Ready to go!"}
          </div>
          
          {isAuthenticated && !databaseReady && (
            <div className="mt-4 p-3 bg-blue-50 dark:bg-blue-900/30 border border-blue-200 dark:border-blue-800 rounded-lg">
              <div className="text-blue-800 dark:text-blue-300 text-xs">
                <strong>First time setup:</strong> This may take a few moments as we set up your local database and sync with remote servers.
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
    
  );
};

const MainApp: React.FC = () => {
  const { state } = useApp();
  const { state: authState } = useAuth();

  // Show database loading screen if authenticated but database not ready
  if (authState.isAuthenticated && !authState.databaseReady) {
    return (
      <DatabaseLoadingScreen 
        isAuthenticated={authState.isAuthenticated}
        databaseReady={authState.databaseReady}
        user={authState.user}
      />
    );
  }

  

  // Show loading screen while POS data is being initialized
  if (authState.databaseReady && state.isLoading && !state.isInitialized) {
    return (
      <div className="h-screen flex items-center justify-center bg-gray-50 dark:bg-gray-950">
        <div className="text-center">
          <div className="w-12 h-12 border-4 border-red-500 border-t-transparent rounded-full animate-spin mx-auto mb-4"></div>
          <p className="text-gray-600 dark:text-gray-400">
            Loading your workspace...
          </p>
          <p className="text-sm text-gray-500 dark:text-gray-500 mt-2">
            Welcome {authState.user?.fullName}
          </p>
        </div>
      </div>
    );
  }

  // Show error state if there's an error
  if (state.error) {
    return (
      <div className="h-screen flex items-center justify-center bg-gray-50 dark:bg-gray-950">
        <div className="text-center p-8">
          <div className="w-16 h-16 bg-red-100 dark:bg-red-900/30 rounded-full flex items-center justify-center mx-auto mb-4">
            <svg className="w-8 h-8 text-red-600 dark:text-red-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.732-.833-2.5 0L4.268 18.5c-.77.833.192 2.5 1.732 2.5z" />
            </svg>
          </div>
          <h1 className="text-2xl font-bold text-gray-900 dark:text-white mb-2">
            System Error
          </h1>
          <p className="text-gray-600 dark:text-gray-400 mb-6">
            {state.error}
          </p>
          <div className="space-y-2">
            <button
              onClick={() => window.location.reload()}
              className="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors mr-2"
            >
              Retry
            </button>
            <button
              onClick={() => {
                if (typeof window !== 'undefined' && (window as any).runDatabaseTests) {
                  (window as any).runDatabaseTests();
                }
              }}
              className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
            >
              Run DB Tests
            </button>
          </div>
        </div>
      </div>
    );
  }

 const renderCurrentView = () => {
  // Check if user needs to select a location
  if (authState.company?.locations?.length > 1 && !state.currentLocationId) {
    return (
      <div className="flex-1 flex items-center justify-center bg-gray-50 dark:bg-gray-950">
        <div className="text-center p-8 max-w-md">
          <div className="w-16 h-16 bg-blue-100 dark:bg-blue-900/30 rounded-full flex items-center justify-center mx-auto mb-4">
            <MapPin className="w-8 h-8 text-blue-600 dark:text-blue-400" />
          </div>
          <h2 className="text-xl font-bold text-gray-800 dark:text-white mb-4">
            Select Location
          </h2>
          <p className="text-gray-600 dark:text-gray-400 mb-6">
            Please select a location to continue
          </p>
          <div className="space-y-2">
            {authState.company.locations.map((location) => (
              <button
                key={location._id}
                // onClick={() => {
                //   dispatch({ type: 'SET_CURRENT_LOCATION', payload: location._id });
                // }}
                className="w-full p-3 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors"
              >
                <div className="font-medium text-gray-800 dark:text-white">{location.name}</div>
                <div className="text-sm text-gray-500 dark:text-gray-400">{location.address}</div>
              </button>
            ))}
          </div>
        </div>
      </div>
    );
  }

  switch (state.currentView) {
    case 'dashboard':
      return <Dashboard />;
    case 'sales':
      return <SalesInterface />;
    case 'inventory':
      return <ProductManagement />;
    case 'customers':
      return <CustomerManagement />;
    default:
      return <Dashboard />;
  }
};

  return (
    <ErrorBoundary>
      <MainLayout>
        <div className="h-full flex flex-col">
          {/* Sync Status Banner */}
          {state.syncStatus === 'offline' && (
            <div className="bg-yellow-100 dark:bg-yellow-900/30 border-b border-yellow-200 dark:border-yellow-800 px-4 py-2">
              <div className="flex items-center justify-center space-x-2">
                <div className="w-2 h-2 bg-yellow-500 rounded-full"></div>
                <span className="text-yellow-800 dark:text-yellow-300 text-sm">
                  Working offline - Changes will sync when connection is restored
                </span>
              </div>
            </div>
          )}
          
          {state.syncStatus === 'error' && (
            <div className="bg-red-100 dark:bg-red-900/30 border-b border-red-200 dark:border-red-800 px-4 py-2">
              <div className="flex items-center justify-center space-x-2">
                <div className="w-2 h-2 bg-red-500 rounded-full"></div>
                <span className="text-red-800 dark:text-red-300 text-sm">
                  Sync error - Some changes may not be saved
                </span>
              </div>
            </div>
          )}

          {state.isSyncing && (
            <div className="bg-blue-100 dark:bg-blue-900/30 border-b border-blue-200 dark:border-blue-800 px-4 py-2">
              <div className="flex items-center justify-center space-x-2">
                <div className="w-2 h-2 bg-blue-500 rounded-full animate-pulse"></div>
                <span className="text-blue-800 dark:text-blue-300 text-sm">
                  Syncing data...
                </span>
              </div>
            </div>
          )}
          
          {/* Main Content */}
          <div className="flex-1 overflow-hidden">
            {renderCurrentView()}
          </div>
        </div>
      </MainLayout>
    </ErrorBoundary>
  );
};

export default MainApp;