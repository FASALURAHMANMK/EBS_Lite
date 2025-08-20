import { useEffect } from 'react';
import { useRouter } from 'next/router';
import { useAuth } from '../context/AuthContext';
import { useAppActions } from '../context/MainContext';
import { LoginPage } from '../components/Auth/LoginPage';

const Login: React.FC = () => {
  const { state, hasRole } = useAuth();
  const { setCurrentCompany, setCurrentLocation } = useAppActions();
  const router = useRouter();

  useEffect(() => {
    if (state.isAuthenticated && state.company) {
      setCurrentCompany(state.company._id);
      const defaultLocation = state.company.locations?.[0]?._id;
      if (defaultLocation) {
        setCurrentLocation(defaultLocation);
      }
      const target = hasRole('Admin') ? '/dashboard' : '/sales';
      router.replace(target);
    }
  }, [state.isAuthenticated, state.company, hasRole, router, setCurrentCompany, setCurrentLocation]);

  return <LoginPage />;
};

export default Login;
