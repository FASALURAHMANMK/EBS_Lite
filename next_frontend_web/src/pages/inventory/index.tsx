import MainLayout from '../../components/Layout/MainLayout';
import RoleGuard from '../../components/Auth/RoleGuard';
import ProductManagement from '../../components/ERP/Inventory/ProductManagement';

const InventoryPage: React.FC = () => (
  <RoleGuard roles={['admin', 'manager', 'store']}>
    <MainLayout>
      <ProductManagement />
    </MainLayout>
  </RoleGuard>
);

export default InventoryPage;
