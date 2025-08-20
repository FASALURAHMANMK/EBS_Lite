import MainLayout from '../../components/Layout/MainLayout';
import RoleGuard from '../../components/Auth/RoleGuard';
import GoodsReceiptForm from '../../components/ERP/Purchase/GoodsReceiptForm';

const GoodsReceiptPage: React.FC = () => (
  <RoleGuard roles={['admin', 'manager']}>
    <MainLayout>
      <GoodsReceiptForm />
    </MainLayout>
  </RoleGuard>
);

export default GoodsReceiptPage;
