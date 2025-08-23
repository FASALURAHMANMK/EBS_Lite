import React, { ReactNode, useEffect } from 'react';
import { useRouter } from 'next/router';
import { useAuth } from '../../context/AuthContext';
import { getInitialRoute } from '../../utils/routes';

interface RoleGuardProps {
  roles: string[];
  children: ReactNode;
}

const RoleGuard: React.FC<RoleGuardProps> = ({ roles, children }) => {
  const { state, hasRole } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (!state.isInitialized) return;
    if (!state.isAuthenticated) {
      router.replace('/login');
    } else if (!hasRole(roles)) {
      router.replace(getInitialRoute(hasRole));
    }
  }, [state.isInitialized, state.isAuthenticated, state.user, roles, router, hasRole]);

  if (!state.isInitialized) {
    return (
      <div className="h-screen flex items-center justify-center">
        <div className="w-8 h-8 border-2 border-red-500 border-t-transparent rounded-full animate-spin"></div>
      </div>
    );
  }

  if (!state.isAuthenticated || !hasRole(roles)) return null;

  return <>{children}</>;
};

export default RoleGuard;
