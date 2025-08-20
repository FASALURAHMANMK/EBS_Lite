import MainLayout from '../../components/Layout/MainLayout';
import RoleGuard from '../../components/Auth/RoleGuard';
import TransferRequest from '../../components/ERP/Inventory/TransferRequest';

const TransferPage: React.FC = () => (
  <RoleGuard roles={['admin', 'manager']}>
    <MainLayout>
      <TransferRequest />
    </MainLayout>
  </RoleGuard>
);

export default TransferPage;
