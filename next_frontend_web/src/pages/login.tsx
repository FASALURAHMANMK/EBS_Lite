import { useEffect } from 'react';
import { useRouter } from 'next/router';
import { useAuth } from '../context/AuthContext';
import { useAppActions } from '../context/MainContext';
import { LoginPage } from '../components/Auth/LoginPage';
import { getInitialRoute } from '../utils/routes';

const Login: React.FC = () => {
  const { state, hasRole } = useAuth();
  const { setCurrentCompany, setCurrentLocation } = useAppActions();
  const router = useRouter();

  useEffect(() => {
    if (state.isAuthenticated && state.company) {
      setCurrentCompany(state.company.companyId);
      const defaultLocation = state.company.locations?.[0]?.locationId;
      if (defaultLocation) {
        setCurrentLocation(defaultLocation);
      }
      const target = getInitialRoute(hasRole);
      router.replace(target);
    }
  }, [state.isAuthenticated, state.company, hasRole, router, setCurrentCompany, setCurrentLocation]);

  return <LoginPage />;
};

export default Login;
