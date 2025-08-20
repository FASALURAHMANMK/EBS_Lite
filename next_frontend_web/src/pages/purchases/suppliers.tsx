import MainLayout from '../../components/Layout/MainLayout';
import RoleGuard from '../../components/Auth/RoleGuard';
import SupplierManagement from '../../components/ERP/Purchase/SupplierManagement';

const SuppliersPage: React.FC = () => (
  <RoleGuard roles={['admin', 'manager']}>
    <MainLayout>
      <SupplierManagement />
    </MainLayout>
  </RoleGuard>
);

export default SuppliersPage;
