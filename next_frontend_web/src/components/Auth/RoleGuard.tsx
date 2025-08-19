import React, { ReactNode, useEffect } from 'react';
import { useRouter } from 'next/router';
import { useAuth } from '../../context/AuthContext';

interface RoleGuardProps {
  roles: Array<'admin' | 'manager' | 'user'>;
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
      router.replace('/dashboard');
    }
  }, [state.isInitialized, state.isAuthenticated, state.user, roles, router, hasRole]);

  if (!state.isAuthenticated || !hasRole(roles)) return null;

  return <>{children}</>;
};

export default RoleGuard;
