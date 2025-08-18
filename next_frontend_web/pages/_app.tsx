import React, { useState } from 'react';
import { AuthProvider, useAuth } from '../context/AuthContext';
import { POSProvider } from '../context/MainContext';
import { LoginPage} from '../components/Auth/LoginPage';
import { RegisterPage } from '../components/Auth/RegisterPage';
import MainApp from '../components/MainApp';
import '../styles/globals.css';
import '../utils/dbTest';

// Loading Component
const LoadingScreen: React.FC = () => {
  return (
    <div className="min-h-screen bg-gradient-to-br from-red-50 to-red-100 dark:from-gray-900 dark:to-gray-800 flex items-center justify-center">
      <div className="text-center">
        <div className="w-16 h-16 bg-gradient-to-r from-red-500 to-red-600 rounded-2xl flex items-center justify-center mx-auto mb-6 shadow-lg">
          <span className="text-white font-bold text-xl">iQ</span>
        </div>
        <h1 className="text-2xl font-bold text-gray-800 dark:text-white mb-4">IQ Spare</h1>
        <div className="w-8 h-8 border-4 border-red-500 border-t-transparent rounded-full animate-spin mx-auto mb-4"></div>
        <p className="text-gray-600 dark:text-gray-400">Loading your business suite...</p>
      </div>
    </div>
  );
};

// Auth Wrapper Component
const AuthWrapper: React.FC = () => {
  const { state } = useAuth();
  const [showRegister, setShowRegister] = useState(false);

  if (!state.isInitialized) {
    return <LoadingScreen />;
  }

  if (!state.isAuthenticated) {
    if (showRegister) {
      return (
        <div>
          <RegisterPage />
          <div className="fixed bottom-4 left-1/2 transform -translate-x-1/2">
            <button
              onClick={() => setShowRegister(false)}
              className="text-gray-600 dark:text-gray-400 hover:text-gray-800 dark:hover:text-gray-200 text-sm"
            >
              Already have an account? Sign in
            </button>
          </div>
        </div>
      );
    }

    return (
      <div>
        <LoginPage />
        <div className="fixed bottom-4 left-1/2 transform -translate-x-1/2">
          <button
            onClick={() => setShowRegister(true)}
            className="text-gray-600 dark:text-gray-400 hover:text-gray-800 dark:hover:text-gray-200 text-sm"
          >
            Don't have an account? Sign up
          </button>
        </div>
      </div>
    );
  }

  return (
    <MainApp />
  );
};

const MyApp: React.FC = () => {
  return (
    <AuthProvider>
      <POSProvider>
        <AuthWrapper />
      </POSProvider>
    </AuthProvider>
  );
};

export default MyApp;