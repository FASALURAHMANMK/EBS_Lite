import { useEffect } from 'react';
import { useRouter } from 'next/router';
import { useAuth } from '../context/AuthContext';

const IndexPage: React.FC = () => {
  const { state } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (state.isAuthenticated) {
      router.replace('/dashboard');
    } else {
      router.replace('/login');
    }
  }, [state.isAuthenticated, router]);

  return null;
};

export default IndexPage;
