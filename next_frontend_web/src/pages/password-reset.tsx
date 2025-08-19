import { useEffect } from 'react';
import { useRouter } from 'next/router';
import { useAuth } from '../context/AuthContext';
import { PasswordResetPage } from '../components/Auth/PasswordResetPage';

const PasswordReset: React.FC = () => {
  const { state } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (state.isAuthenticated) {
      router.replace('/dashboard');
    }
  }, [state.isAuthenticated, router]);

  return <PasswordResetPage />;
};

export default PasswordReset;
