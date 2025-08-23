import { useEffect } from 'react';
import { useRouter } from 'next/router';
import { useAuth } from '../../context/AuthContext';
import MainLayout from '../../components/Layout/MainLayout';
import PurchaseOrderForm from '../../components/ERP/Purchase/PurchaseOrderForm';

const PurchaseOrderPage: React.FC = () => {
  const { state, hasRole } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (!state.isInitialized) return;
    if (!state.isAuthenticated) {
      router.replace('/login');
    }
  }, [state.isInitialized, state.isAuthenticated, router]);

  if (!state.isInitialized || !state.isAuthenticated) return null;
  if (!hasRole(['1', 'manager'])) return <div>Access denied</div>;

  return (
    <MainLayout>
      <PurchaseOrderForm />
    </MainLayout>
  );
};

export default PurchaseOrderPage;
