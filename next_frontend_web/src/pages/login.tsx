import { useEffect } from 'react';
import { useRouter } from 'next/router';
import { useAuth } from '../context/AuthContext';
import { LoginPage } from '../components/Auth/LoginPage';

const Login: React.FC = () => {
  const { state } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (state.isAuthenticated) {
      router.replace('/dashboard');
    }
  }, [state.isAuthenticated, router]);

  return <LoginPage />;
};

export default Login;
