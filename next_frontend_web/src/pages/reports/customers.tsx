import MainLayout from '../../components/Layout/MainLayout';
import CustomersReport from '../../components/ERP/Reports/CustomersReport';
import RoleGuard from '../../components/Auth/RoleGuard';

const CustomersReportPage: React.FC = () => (
  <RoleGuard roles={['admin', 'manager']}>
    <MainLayout>
      <CustomersReport />
    </MainLayout>
  </RoleGuard>
);

export default CustomersReportPage;
