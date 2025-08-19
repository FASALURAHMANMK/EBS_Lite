import MainLayout from '../../components/Layout/MainLayout';
import SalesInterface from '../../components/ERP/Sales/SalesInterface';
import RoleGuard from '../../components/Auth/RoleGuard';

const SalesPage: React.FC = () => (
  <RoleGuard roles={['admin', 'manager']}>
    <MainLayout>
      <SalesInterface />
    </MainLayout>
  </RoleGuard>
);

export default SalesPage;
