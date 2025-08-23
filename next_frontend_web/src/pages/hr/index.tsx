import { useEffect } from 'react';
import { useRouter } from 'next/router';
import { useAuth } from '../../context/AuthContext';
import MainLayout from '../../components/Layout/MainLayout';
import Link from 'next/link';

const HRDashboard: React.FC = () => {
  const { state, hasRole } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (!state.isInitialized) return;
    if (!state.isAuthenticated) {
      router.replace('/login');
    }
  }, [state.isInitialized, state.isAuthenticated, router]);

  if (!state.isInitialized || !state.isAuthenticated) return null;
  if (!hasRole(['1', 'HR'])) return <div>Access denied</div>;

  return (
    <MainLayout>
      <div className="p-6 space-y-4">
        <h1 className="text-2xl font-bold">Human Resources</h1>
        <ul className="list-disc pl-6 space-y-1">
          <li>
            <Link href="/hr/clock" className="text-blue-600 hover:underline">
              Clock In/Out
            </Link>
          </li>
          <li>
            <Link href="/hr/leave" className="text-blue-600 hover:underline">
              Leave Calendar
            </Link>
          </li>
          <li>
            <Link href="/hr/payroll" className="text-blue-600 hover:underline">
              Salary Processing
            </Link>
          </li>
        </ul>
      </div>
    </MainLayout>
  );
};

export default HRDashboard;
