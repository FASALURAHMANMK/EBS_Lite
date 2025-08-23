import { useEffect } from 'react';
import { useRouter } from 'next/router';
import { useAuth } from '../context/AuthContext';
import { getInitialRoute } from '../utils/routes';

const IndexPage: React.FC = () => {
  const { state, hasRole } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (state.isAuthenticated) {
      router.replace(getInitialRoute(hasRole));
    } else {
      router.replace('/login');
    }
  }, [state.isAuthenticated, hasRole, router]);

  return null;
};

export default IndexPage;
