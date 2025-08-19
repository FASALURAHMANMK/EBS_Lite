import MainLayout from '../../components/Layout/MainLayout';
import Dashboard from '../../components/ERP/Dashboard';
import RoleGuard from '../../components/Auth/RoleGuard';

const DashboardPage: React.FC = () => (
  <RoleGuard roles={['admin', 'manager', 'user']}>
    <MainLayout>
      <Dashboard />
    </MainLayout>
  </RoleGuard>
);

export default DashboardPage;
