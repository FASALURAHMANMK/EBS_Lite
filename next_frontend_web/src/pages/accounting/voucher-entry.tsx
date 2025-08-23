import { useEffect } from 'react';
import { useRouter } from 'next/router';
import { useAuth } from '../../context/AuthContext';
import MainLayout from '../../components/Layout/MainLayout';
import VoucherEntry from '../../components/ERP/Accounting/VoucherEntry';
import { ROLES } from '../../types';

const VoucherEntryPage: React.FC = () => {
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
      <VoucherEntry />
    </MainLayout>
  );
};

export default VoucherEntryPage;
