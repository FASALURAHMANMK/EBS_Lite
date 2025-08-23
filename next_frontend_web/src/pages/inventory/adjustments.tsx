import { useEffect } from 'react';
import { useRouter } from 'next/router';
import { useAuth } from '../../context/AuthContext';
import MainLayout from '../../components/Layout/MainLayout';
import StockAdjustments from '../../components/ERP/Inventory/StockAdjustments';
import { ROLES } from '../../types';

const StockAdjustmentsPage: React.FC = () => {
  const { state, hasRole } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (!state.isInitialized) return;
    if (!state.isAuthenticated) {
      router.replace('/login');
    }
  }, [state.isInitialized, state.isAuthenticated, router]);

  if (!state.isInitialized || !state.isAuthenticated) return null;
  if (!hasRole([ROLES.SUPER_ADMIN, ROLES.ADMIN, ROLES.MANAGER])) return <div>Access denied</div>;

  return (
    <MainLayout>
      <StockAdjustments />
    </MainLayout>
  );
};

export default StockAdjustmentsPage;
