import React from 'react';
import Header from './Header';
import Sidebar from './Sidebar';
import { useApp } from '../../context/MainContext';

interface MainLayoutProps {
  children: React.ReactNode;
}

const MainLayout: React.FC<MainLayoutProps> = ({ children }) => {
  const { state } = useApp();

  return (
    <div className={`h-screen flex flex-col bg-gray-50 dark:bg-gray-950 ${state.theme}`}>
      <Header />
      <div className="flex-1 flex overflow-hidden">
        <Sidebar />
        <main className={`flex-1 overflow-hidden transition-all duration-300 ${
          state.sidebarCollapsed ? 'ml-0' : 'ml-0'
        }`}>
          <div className="h-full overflow-y-auto bg-gray-50 dark:bg-gray-950">
            {children}
          </div>
        </main>
      </div>
    </div>
  );
};

export default MainLayout;