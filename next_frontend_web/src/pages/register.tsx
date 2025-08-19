import { useEffect } from 'react';
import { useRouter } from 'next/router';
import { useAuth } from '../context/AuthContext';
import { RegisterPage } from '../components/Auth/RegisterPage';

const Register: React.FC = () => {
  const { state } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (state.isAuthenticated) {
      const target = state.user?.role === 'admin' ? '/dashboard' : '/sales';
      router.replace(target);
    }
  }, [state.isAuthenticated, state.user, router]);

  return <RegisterPage />;
};

export default Register;
