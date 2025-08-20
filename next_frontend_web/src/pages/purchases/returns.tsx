import MainLayout from '../../components/Layout/MainLayout';
import RoleGuard from '../../components/Auth/RoleGuard';
import PurchaseReturnForm from '../../components/ERP/Purchase/PurchaseReturnForm';

const PurchaseReturnPage: React.FC = () => (
  <RoleGuard roles={['admin', 'manager']}>
    <MainLayout>
      <PurchaseReturnForm />
    </MainLayout>
  </RoleGuard>
);

export default PurchaseReturnPage;
