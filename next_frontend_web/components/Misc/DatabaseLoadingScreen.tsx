import React from 'react';
import { Database, Loader, CheckCircle, AlertCircle } from 'lucide-react';

interface DatabaseLoadingScreenProps {
  isAuthenticated: boolean;
  databaseReady: boolean;
  user?: { fullName?: string } | null;
}

const DatabaseLoadingScreen: React.FC<DatabaseLoadingScreenProps> = ({ 
  isAuthenticated, 
  databaseReady, 
  user 
}) => {
  const getStatus = () => {
    if (isAuthenticated && databaseReady) {
      return {
        icon: CheckCircle,
        color: 'text-green-600 dark:text-green-400',
        bgColor: 'bg-green-100 dark:bg-green-900/30',
        title: 'Ready!',
        message: 'Database initialized successfully'
      };
    } else if (isAuthenticated && !databaseReady) {
      return {
        icon: Database,
        color: 'text-blue-600 dark:text-blue-400',
        bgColor: 'bg-blue-100 dark:bg-blue-900/30',
        title: 'Initializing Database...',
        message: 'Setting up your workspace'
      };
    } else {
      return {
        icon: Loader,
        color: 'text-gray-600 dark:text-gray-400',
        bgColor: 'bg-gray-100 dark:bg-gray-900/30',
        title: 'Loading...',
        message: 'Preparing application'
      };
    }
  };

  const status = getStatus();
  const StatusIcon = status.icon;

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
        <div className={`inline-flex items-center space-x-3 px-6 py-4 rounded-xl ${status.bgColor} mb-6`}>
          <StatusIcon className={`w-6 h-6 ${status.color} ${!databaseReady ? 'animate-spin' : ''}`} />
          <div>
            <div className={`font-medium ${status.color}`}>
              {status.title}
            </div>
            <div className="text-sm text-gray-600 dark:text-gray-400">
              {status.message}
            </div>
          </div>
        </div>

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

        {/* Debug Info (only in development) */}
        {process.env.NODE_ENV === 'development' && (
          <div className="mt-8 p-4 bg-gray-100 dark:bg-gray-800 rounded-lg text-left max-w-md mx-auto">
            <h4 className="text-sm font-medium text-gray-800 dark:text-white mb-2">
              Debug Info:
            </h4>
            <div className="text-xs text-gray-600 dark:text-gray-400 space-y-1">
              <div>Authenticated: {isAuthenticated ? '✅' : '❌'}</div>
              <div>Database Ready: {databaseReady ? '✅' : '❌'}</div>
              <div>User: {user?.fullName || 'None'}</div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

export default DatabaseLoadingScreen;