import { useEffect } from 'react';
import { useRouter } from 'next/router';
import { useAuth } from '../context/AuthContext';
import { LoginPage } from '../components/Auth/LoginPage';

const Login: React.FC = () => {
  const { state, hasRole } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (state.isAuthenticated) {
      const target = hasRole('Admin') ? '/dashboard' : '/sales';
      router.replace(target);
    }
  }, [state.isAuthenticated, hasRole, router]);

  return <LoginPage />;
};

export default Login;
