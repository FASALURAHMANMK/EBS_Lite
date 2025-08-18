import React from 'react';
import { AlertCircle, RefreshCw, Database, Wifi, WifiOff } from 'lucide-react';
import { useApp } from '../../context/MainContext';
import { useAuth } from '../../context/AuthContext';

interface ErrorDisplayProps {
  error: string;
  onRetry?: () => void;
  onClearError?: () => void;
}

const ErrorDisplay: React.FC<ErrorDisplayProps> = ({ error, onRetry, onClearError }) => {
  const { state } = useApp();
  const { state: authState } = useAuth();

  const getErrorType = (errorMessage: string) => {
    if (errorMessage.includes('Database')) return 'database';
    if (errorMessage.includes('connection') || errorMessage.includes('network')) return 'network';
    if (errorMessage.includes('timeout')) return 'timeout';
    if (errorMessage.includes('company') || errorMessage.includes('auth')) return 'auth';
    return 'general';
  };

  const getErrorIcon = (type: string) => {
    switch (type) {
      case 'database': return Database;
      case 'network': return state.syncStatus === 'offline' ? WifiOff : Wifi;
      case 'timeout': return RefreshCw;
      default: return AlertCircle;
    }
  };

  const getErrorColor = (type: string) => {
    switch (type) {
      case 'network': return 'yellow';
      case 'database': return 'red';
      case 'timeout': return 'blue';
      default: return 'red';
    }
  };

  const errorType = getErrorType(error);
  const ErrorIcon = getErrorIcon(errorType);
  const colorClass = getErrorColor(errorType);

  return (
    <div className={`bg-${colorClass}-50 dark:bg-${colorClass}-900/30 border border-${colorClass}-200 dark:border-${colorClass}-800 rounded-lg p-4 mb-4`}>
      <div className="flex items-start space-x-3">
        <ErrorIcon className={`w-5 h-5 text-${colorClass}-600 dark:text-${colorClass}-400 mt-0.5 flex-shrink-0`} />
        <div className="flex-1">
          <h4 className={`font-medium text-${colorClass}-800 dark:text-${colorClass}-300 mb-1`}>
            {errorType === 'database' && 'Database Error'}
            {errorType === 'network' && 'Connection Issue'}
            {errorType === 'timeout' && 'Timeout Error'}
            {errorType === 'auth' && 'Authentication Error'}
            {errorType === 'general' && 'Application Error'}
          </h4>
          <p className={`text-sm text-${colorClass}-700 dark:text-${colorClass}-400 mb-3`}>
            {error}
          </p>
          
          {/* Status Information */}
          <div className="text-xs space-y-1 mb-3">
            <div className="flex items-center space-x-2">
              <span className={`text-${colorClass}-600 dark:text-${colorClass}-400`}>Sync Status:</span>
              <span className={
                state.syncStatus === 'online' ? 'text-green-600' :
                state.syncStatus === 'offline' ? 'text-yellow-600' : 'text-red-600'
              }>
                {state.syncStatus.charAt(0).toUpperCase() + state.syncStatus.slice(1)}
              </span>
            </div>
            <div className="flex items-center space-x-2">
              <span className={`text-${colorClass}-600 dark:text-${colorClass}-400`}>Company:</span>
              <span>{authState.user?.companyId ? 'Connected' : 'Not Connected'}</span>
            </div>
          </div>

          {/* Action Buttons */}
          <div className="flex space-x-2">
            {onRetry && (
              <button
                onClick={onRetry}
                className={`px-3 py-1 bg-${colorClass}-600 text-white rounded text-sm hover:bg-${colorClass}-700 transition-colors flex items-center space-x-1`}
              >
                <RefreshCw className="w-3 h-3" />
                <span>Retry</span>
              </button>
            )}
            {onClearError && (
              <button
                onClick={onClearError}
                className="px-3 py-1 bg-gray-600 text-white rounded text-sm hover:bg-gray-700 transition-colors"
              >
                Dismiss
              </button>
            )}
            <button
              onClick={() => window.location.reload()}
              className="px-3 py-1 bg-gray-600 text-white rounded text-sm hover:bg-gray-700 transition-colors"
            >
              Refresh App
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

export default ErrorDisplay;