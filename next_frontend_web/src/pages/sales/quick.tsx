import { useEffect, useState } from 'react';
import { useRouter } from 'next/router';
import { useAuth } from '../../context/AuthContext';
import MainLayout from '../../components/Layout/MainLayout';
import QuickSale, { QuickSaleItem } from '../../components/ERP/Sales/QuickSale';
import { ROLES } from '../../types';

const QuickSalesPage: React.FC = () => {
  const { state, hasRole } = useAuth();
  const router = useRouter();
  const [items, setItems] = useState<QuickSaleItem[]>([]);

  useEffect(() => {
    if (!state.isInitialized) return;
    if (!state.isAuthenticated) {
      router.replace('/login');
    }
  }, [state.isInitialized, state.isAuthenticated, router]);

  useEffect(() => {
    const saved = localStorage.getItem('quick-sale-items');
    if (saved) {
      try {
        setItems(JSON.parse(saved));
      } catch {
        // ignore parse errors
      }
    }
  }, []);

  useEffect(() => {
    localStorage.setItem('quick-sale-items', JSON.stringify(items));
  }, [items]);

  if (!state.isInitialized || !state.isAuthenticated) return null;
  if (!hasRole([ROLES.SUPER_ADMIN, ROLES.ADMIN, ROLES.MANAGER, ROLES.SALES])) return <div>Access denied</div>;

  return (
    <MainLayout>
      <QuickSale items={items} onChange={setItems} />
    </MainLayout>
  );
};

export default QuickSalesPage;
