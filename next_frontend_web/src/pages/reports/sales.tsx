import MainLayout from '../../components/Layout/MainLayout';
import SalesReport from '../../components/ERP/Reports/SalesReport';
import RoleGuard from '../../components/Auth/RoleGuard';

const SalesReportPage: React.FC = () => (
  <RoleGuard roles={['admin', 'manager']}>
    <MainLayout>
      <SalesReport />
    </MainLayout>
  </RoleGuard>
);

export default SalesReportPage;
