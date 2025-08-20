import MainLayout from '../../components/Layout/MainLayout';
import SalesHistory from '../../components/ERP/Sales/SalesHistory';
import RoleGuard from '../../components/Auth/RoleGuard';

const SalesHistoryPage: React.FC = () => (
  <RoleGuard roles={['admin', 'manager']}>
    <MainLayout>
      <SalesHistory />
    </MainLayout>
  </RoleGuard>
);

export default SalesHistoryPage;
