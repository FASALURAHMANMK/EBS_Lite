import MainLayout from '../../components/Layout/MainLayout';
import RoleGuard from '../../components/Auth/RoleGuard';
import PurchaseOrderForm from '../../components/ERP/Purchase/PurchaseOrderForm';

const PurchaseOrderPage: React.FC = () => (
  <RoleGuard roles={['admin', 'manager']}>
    <MainLayout>
      <PurchaseOrderForm />
    </MainLayout>
  </RoleGuard>
);

export default PurchaseOrderPage;
