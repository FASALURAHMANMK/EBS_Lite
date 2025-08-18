import { useEffect } from 'react';
import { useRouter } from 'next/router';
import { useAuth } from '../context/AuthContext';
import { RegisterPage } from '../components/Auth/RegisterPage';

const Register: React.FC = () => {
  const { state } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (state.isAuthenticated) {
      router.replace('/dashboard');
    }
  }, [state.isAuthenticated, router]);

  return <RegisterPage />;
};

export default Register;
