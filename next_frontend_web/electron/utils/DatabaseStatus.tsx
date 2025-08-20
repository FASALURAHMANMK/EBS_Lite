// NOTE: Reserved for future desktop offline mode. Not used in web builds.
import React, { useState, useEffect } from 'react';
import { Database, Wifi, WifiOff, CheckCircle, XCircle, RefreshCw, Play } from 'lucide-react';

interface DatabaseStatusProps {
  className?: string;
}

const DatabaseStatus: React.FC<DatabaseStatusProps> = ({ className = '' }) => {
  const [status, setStatus] = useState({
    online: false,
    initialized: false,
    lastCheck: null as Date | null
  });
  const [isLoading, setIsLoading] = useState(false);
  const [testResults, setTestResults] = useState<any[]>([]);
  const [showDetails, setShowDetails] = useState(false);

  useEffect(() => {
    checkDatabaseStatus();
    
    // Listen for database sync events
    const handleSyncEvent = (event: any) => {
      const { type } = event.detail;
      if (type === 'online' || type === 'offline' || type === 'initialized') {
        checkDatabaseStatus();
      }
    };

    if (typeof window !== 'undefined') {
      window.addEventListener('db-sync', handleSyncEvent);
      return () => window.removeEventListener('db-sync', handleSyncEvent);
    }
  }, []);

  const checkDatabaseStatus = async () => {
    try {
      if (typeof window !== 'undefined' && window.DatabaseTester) {
        const tester = new window.DatabaseTester();
        const statusInfo = tester.getStatus();
        setStatus({
          ...statusInfo,
          lastCheck: new Date()
        });
      } else {
        setStatus({
          online: false,
          initialized: false,
          lastCheck: new Date()
        });
      }
    } catch (error) {
      console.error('Error checking database status:', error);
      setStatus({
        online: false,
        initialized: false,
        lastCheck: new Date()
      });
    }
  };

  const runTests = async () => {
    if (typeof window === 'undefined' || !window.runDatabaseTests) {
      alert('Database tests are unavailable in this environment.');
      return;
    }
    setIsLoading(true);
    try {
      const results = await window.runDatabaseTests();
      setTestResults(results.results);
      setShowDetails(true);
      await checkDatabaseStatus();
    } catch (error) {
      console.error('Error running tests:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const initializeWithSampleData = async () => {
    if (typeof window === 'undefined' || !window.initializeDatabaseWithSampleData) {
      alert('Sample data initialization is unavailable in this environment.');
      return;
    }
    if (window.confirm('This will clear all existing data and create sample data. Continue?')) {
      setIsLoading(true);
      try {
        await window.initializeDatabaseWithSampleData();
        await checkDatabaseStatus();
        alert('Database initialized with sample data successfully!');
      } catch (error: any) {
        console.error('Error initializing database:', error);
        alert('Error initializing database: ' + error.message);
      } finally {
        setIsLoading(false);
      }
    }
  };

  const getStatusColor = () => {
    if (status.initialized && status.online) return 'text-green-600 dark:text-green-400';
    if (status.initialized && !status.online) return 'text-yellow-600 dark:text-yellow-400';
    return 'text-red-600 dark:text-red-400';
  };

  const getStatusIcon = () => {
    if (status.initialized && status.online) return Wifi;
    if (status.initialized && !status.online) return Database;
    return WifiOff;
  };

  const getStatusText = () => {
    if (status.initialized && status.online) return 'Online & Syncing';
    if (status.initialized && !status.online) return 'Offline Mode';
    return 'Not Initialized';
  };

  const StatusIcon = getStatusIcon();

  return (
    <div className={`bg-white dark:bg-gray-900 rounded-lg border border-gray-200 dark:border-gray-700 p-4 ${className}`}>
      <div className="flex items-center justify-between mb-4">
        <h3 className="text-lg font-semibold text-gray-800 dark:text-white flex items-center">
          <Database className="w-5 h-5 mr-2" />
          Database Status
        </h3>
        <button
          onClick={checkDatabaseStatus}
          disabled={isLoading}
          className="p-2 text-gray-600 dark:text-gray-400 hover:text-gray-800 dark:hover:text-gray-200 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors"
          title="Refresh Status"
        >
          <RefreshCw className={`w-4 h-4 ${isLoading ? 'animate-spin' : ''}`} />
        </button>
      </div>

      {/* Status Display */}
      <div className="flex items-center space-x-3 mb-4">
        <StatusIcon className={`w-6 h-6 ${getStatusColor()}`} />
        <div>
          <div className={`font-medium ${getStatusColor()}`}>
            {getStatusText()}
          </div>
          {status.lastCheck && (
            <div className="text-xs text-gray-500 dark:text-gray-400">
              Last checked: {status.lastCheck.toLocaleTimeString()}
            </div>
          )}
        </div>
      </div>

      {/* Status Details */}
      <div className="grid grid-cols-2 gap-4 mb-4 text-sm">
        <div className="flex items-center space-x-2">
          {status.initialized ? (
            <CheckCircle className="w-4 h-4 text-green-600 dark:text-green-400" />
          ) : (
            <XCircle className="w-4 h-4 text-red-600 dark:text-red-400" />
          )}
          <span className="text-gray-700 dark:text-gray-300">
            {status.initialized ? 'Initialized' : 'Not Initialized'}
          </span>
        </div>
        <div className="flex items-center space-x-2">
          {status.online ? (
            <Wifi className="w-4 h-4 text-green-600 dark:text-green-400" />
          ) : (
            <WifiOff className="w-4 h-4 text-gray-600 dark:text-gray-400" />
          )}
          <span className="text-gray-700 dark:text-gray-300">
            {status.online ? 'Remote Sync' : 'Local Only'}
          </span>
        </div>
      </div>

      {/* Action Buttons */}
      <div className="flex flex-wrap gap-2">
        <button
          onClick={runTests}
          disabled={isLoading}
          className="flex items-center space-x-2 px-3 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed text-sm"
        >
          <Play className="w-4 h-4" />
          <span>Run Tests</span>
        </button>
        
        <button
          onClick={initializeWithSampleData}
          disabled={isLoading}
          className="flex items-center space-x-2 px-3 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed text-sm"
        >
          <Database className="w-4 h-4" />
          <span>Sample Data</span>
        </button>
        
        <button
          onClick={() => setShowDetails(!showDetails)}
          className="flex items-center space-x-2 px-3 py-2 bg-gray-600 text-white rounded-lg hover:bg-gray-700 text-sm"
        >
          <span>{showDetails ? 'Hide' : 'Show'} Details</span>
        </button>
      </div>

      {/* Test Results */}
      {showDetails && testResults.length > 0 && (
        <div className="mt-4 border-t border-gray-200 dark:border-gray-700 pt-4">
          <h4 className="font-medium text-gray-800 dark:text-white mb-2">Test Results:</h4>
          <div className="space-y-2">
            {testResults.map((result, index) => (
              <div
                key={index}
                className={`flex items-start space-x-2 p-2 rounded text-sm ${
                  result.success
                    ? 'bg-green-50 dark:bg-green-900/30 text-green-800 dark:text-green-300'
                    : 'bg-red-50 dark:bg-red-900/30 text-red-800 dark:text-red-300'
                }`}
              >
                {result.success ? (
                  <CheckCircle className="w-4 h-4 mt-0.5 flex-shrink-0" />
                ) : (
                  <XCircle className="w-4 h-4 mt-0.5 flex-shrink-0" />
                )}
                <div className="flex-1">
                  <div className="font-medium">{result.test}</div>
                  <div className="text-xs opacity-75">
                    {result.success ? result.message : result.error}
                  </div>
                  {result.data && (
                    <div className="text-xs opacity-75 mt-1">
                      Data: {JSON.stringify(result.data)}
                    </div>
                  )}
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Tips */}
      {!status.initialized && (
        <div className="mt-4 p-3 bg-yellow-50 dark:bg-yellow-900/30 border border-yellow-200 dark:border-yellow-800 rounded-lg">
          <div className="text-yellow-800 dark:text-yellow-300 text-sm">
            <strong>Tip:</strong> If the database is not initialized, try running tests or creating sample data to set up the application.
          </div>
        </div>
      )}

      {status.initialized && !status.online && (
        <div className="mt-4 p-3 bg-blue-50 dark:bg-blue-900/30 border border-blue-200 dark:border-blue-800 rounded-lg">
          <div className="text-blue-800 dark:text-blue-300 text-sm">
            <strong>Info:</strong> Running in offline mode. All data is stored locally and will sync when remote connection is available.
          </div>
        </div>
      )}
    </div>
  );
};

export default DatabaseStatus;