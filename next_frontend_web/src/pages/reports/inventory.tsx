import MainLayout from '../../components/Layout/MainLayout';
import InventoryReport from '../../components/ERP/Reports/InventoryReport';
import RoleGuard from '../../components/Auth/RoleGuard';

const InventoryReportPage: React.FC = () => (
  <RoleGuard roles={['admin', 'manager']}>
    <MainLayout>
      <InventoryReport />
    </MainLayout>
  </RoleGuard>
);

export default InventoryReportPage;
