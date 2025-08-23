import { useEffect } from 'react';
import { useRouter } from 'next/router';
import { useAuth } from '../../context/AuthContext';
import MainLayout from '../../components/Layout/MainLayout';
import ClockInOut from '../../components/ERP/HR/ClockInOut';

const ClockPage: React.FC = () => {
  const { state, hasRole } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (!state.isInitialized) return;
    if (!state.isAuthenticated) {
      router.replace('/login');
    }
  }, [state.isInitialized, state.isAuthenticated, router]);

  if (!state.isInitialized || !state.isAuthenticated) return null;
  if (!hasRole(['Admin', 'HR'])) return <div>Access denied</div>;

  return (
    <MainLayout>
      <ClockInOut />
    </MainLayout>
  );
};

export default ClockPage;
