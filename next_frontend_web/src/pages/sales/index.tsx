import { useEffect } from 'react';
import { useRouter } from 'next/router';
import { useAuth } from '../../context/AuthContext';
import MainLayout from '../../components/Layout/MainLayout';
import SalesInterface from '../../components/ERP/Sales/SalesInterface';

const SalesPage: React.FC = () => {
  const { state } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (!state.isAuthenticated) {
      router.replace('/login');
    }
  }, [state.isAuthenticated, router]);

  if (!state.isAuthenticated) return null;

  return (
    <MainLayout>
      <SalesInterface />
    </MainLayout>
  );
};

export default SalesPage;
