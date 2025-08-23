import { useEffect } from 'react';
import { useRouter } from 'next/router';
import { useAuth } from '../context/AuthContext';
import { RegisterPage } from '../components/Auth/RegisterPage';
import { ROLES } from '../types';

const Register: React.FC = () => {
  const { state, hasRole } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (state.isAuthenticated) {
      const target = hasRole([ROLES.SUPER_ADMIN, ROLES.ADMIN]) ? '/dashboard' : '/sales';
      router.replace(target);
    }
  }, [state.isAuthenticated, hasRole, router]);

  return <RegisterPage />;
};

export default Register;
