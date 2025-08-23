import MainLayout from '../../components/Layout/MainLayout';
import RoleGuard from '../../components/Auth/RoleGuard';
import StockAdjustments from '../../components/ERP/Inventory/StockAdjustments';

const StockAdjustmentsPage: React.FC = () => (
  <RoleGuard roles={['admin', 'manager', 'store']}>
    <MainLayout>
      <StockAdjustments />
    </MainLayout>
  </RoleGuard>
);

export default StockAdjustmentsPage;
