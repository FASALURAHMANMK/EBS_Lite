import MainLayout from '../../components/Layout/MainLayout';
import RoleGuard from '../../components/Auth/RoleGuard';
import SalaryProcessing from '../../components/ERP/HR/SalaryProcessing';

const PayrollPage: React.FC = () => (
  <RoleGuard roles={['admin', 'manager', 'employee']}>
    <MainLayout>
      <SalaryProcessing />
    </MainLayout>
  </RoleGuard>
);

export default PayrollPage;
