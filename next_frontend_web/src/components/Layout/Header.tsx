import React, { useState, useEffect } from 'react';
import { ChevronDown, Sun, Moon, LogOut, Menu, MapPin, RefreshCw, LucideLanguages } from 'lucide-react';
import { useApp } from '../../context/MainContext';
import { useAuth } from '../../context/AuthContext';

const Header: React.FC = () => {
  const { state, dispatch, loadAllData, setCurrentLocation } = useApp();

  const { state: authState, logout } = useAuth();
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [showLocationDropdown, setShowLocationDropdown] = useState(false);

  const handleRefresh = async () => {
    setIsRefreshing(true);
    try {
      await loadAllData();
    } catch (error) {
      console.error('Refresh failed:', error);
    } finally {
      setIsRefreshing(false);
    }
  };

  const handleLogout = () => {
    if (window.confirm('Are you sure you want to logout?')) {
      logout();
    }
  };

  const toggleTheme = () => {
    dispatch({ type: 'TOGGLE_THEME' });
  };

 const handleLocationChange = async (locationId: string) => {
  if (state.isLoading) return;
  
  try {
    await setCurrentLocation(locationId);
    setShowLocationDropdown(false);
  } catch (error) {
    console.error('Failed to change location:', error);
  }
};

  useEffect(() => {
  const handleClickOutside = () => {
    setShowLocationDropdown(false);
  };

  if (showLocationDropdown) {
    document.addEventListener('click', handleClickOutside);
    return () => document.removeEventListener('click', handleClickOutside);
  }
}, [showLocationDropdown]);

  const currentLocation = authState.company?.locations?.find(loc => loc._id === state.currentLocationId);


  return (
    <header className="bg-white dark:bg-gray-900 border-b border-gray-200 dark:border-gray-700 px-4 py-3 flex items-center justify-between shadow-sm">
      <div className="flex items-center space-x-4">
        <button
          onClick={() => dispatch({ type: 'TOGGLE_SIDEBAR' })}
          className="p-2 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors lg"
        >
          <Menu className="w-5 h-5 text-gray-600 dark:text-gray-300" />
        </button>
        
       <div className="flex items-center space-x-3">
          {/* Company Logo */}
          <div className="w-10 h-10 bg-gradient-to-r from-red-500 to-red-600 rounded-xl flex items-center justify-center shadow-md">
            {authState.company?.logo ? (
              <img 
                src={authState.company.logo} 
                alt="Company Logo" 
                className="w-8 h-8 rounded-lg object-cover"
              />
            ) : (
              <span className="text-white font-bold text-sm">
                {authState.company?.name?.charAt(0) || 'C'}
              </span>
            )}
          </div>
          
          {/* Company Info */}
          <div>
            <h1 className="font-bold text-gray-800 dark:text-white text-lg">
              {authState.company?.name || 'Company Name'}
            </h1>
            <p className="text-xs text-gray-500 dark:text-gray-400">
              {authState.company?.settings?.currency || 'INR'} • {authState.company?.settings?.timezone || 'GMT +5:30'}
            </p>
          </div>
        </div>
        
        {/* Location Selector */}
<div className="hidden md:flex items-center space-x-2 relative">
  <button
    onClick={(e) => {
      e.stopPropagation();
      setShowLocationDropdown(!showLocationDropdown);
    }}
    className="flex items-center space-x-2 bg-blue-50 dark:bg-blue-900/30 px-3 py-2 rounded-full hover:bg-blue-100 dark:hover:bg-blue-900/50 transition-colors"
  >
    <MapPin className="w-4 h-4 text-blue-700 dark:text-blue-300" />
    <span className="text-blue-700 dark:text-blue-300 font-medium text-sm">
      {currentLocation?.name || 'Select Location'}
    </span>
    <ChevronDown className="w-4 h-4 text-blue-600 dark:text-blue-400" />
  </button>

  {showLocationDropdown && authState.company?.locations && (
    <div className="absolute top-full left-0 mt-2 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-600 rounded-lg shadow-lg z-50 min-w-48">
      {authState.company.locations.map((location) => (
        <button
          key={location._id}
          onClick={() => handleLocationChange(location._id)}
          disabled={state.isLoading}
          className={`w-full text-left px-4 py-3 hover:bg-gray-50 dark:hover:bg-gray-700 first:rounded-t-lg last:rounded-b-lg transition-colors disabled:opacity-50 ${
            location._id === state.currentLocationId 
              ? 'bg-blue-50 dark:bg-blue-900/30 text-blue-700 dark:text-blue-300' 
              : 'text-gray-800 dark:text-white'
          }`}
        >
          <div className="font-medium">{location.name}</div>
          <div className="text-xs text-gray-500 dark:text-gray-400">{location.address}</div>
          {location._id === state.currentLocationId && (
            <div className="text-xs text-blue-600 dark:text-blue-400 mt-1">Current Location</div>
          )}
        </button>
      ))}
    </div>
  )}
</div>
      </div>

      <div className="flex items-center space-x-2">
        {/* Refresh Button */}
        <button
          onClick={handleRefresh}
          disabled={isRefreshing}
          className="p-2 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors disabled:opacity-50"
          title="Refresh Data"
        >
          <RefreshCw className={`w-5 h-5 text-gray-600 dark:text-gray-300 ${isRefreshing ? 'animate-spin' : ''}`} />
        </button>
        {/* Language Toggle Button */}
        <button
          // onClick={toggleLanguage}
          className="p-2 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors"
          title="Toggle Language"
        >
          <LucideLanguages className="w-5 h-5 text-gray-600 dark:text-gray-300" />
        </button>

        {/* Theme Toggle */}
        <button 
          onClick={toggleTheme}
          className="p-2 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors"
          title={`Switch to ${state.theme === 'light' ? 'dark' : 'light'} mode`}
        >
          {state.theme === 'light' ? (
            <Moon className="w-5 h-5 text-gray-600" />
          ) : (
            <Sun className="w-5 h-5 text-yellow-500" />
          )}
        </button>

        {/* User Menu */}
        <div className="flex items-center space-x-2">
          <div className="hidden md:block text-right">
            <div className="text-sm font-medium text-gray-800 dark:text-white">
              {authState.user?.fullName}
            </div>
            <div className="text-xs text-gray-500 dark:text-gray-400">
              {authState.user?.role}
            </div>
          </div>
          
          {/* Logout Button */}
          <button 
            onClick={handleLogout}
            className="p-2 rounded-lg hover:bg-red-50 dark:hover:bg-red-900/30 transition-colors group"
            title="Logout"
          >
            <LogOut className="w-5 h-5 text-gray-600 dark:text-gray-300 group-hover:text-red-600 dark:group-hover:text-red-400" />
          </button>
        </div>
      </div>
    </header>
  );
};

export default Header;