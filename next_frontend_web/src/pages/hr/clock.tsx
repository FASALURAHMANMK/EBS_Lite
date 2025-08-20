import MainLayout from '../../components/Layout/MainLayout';
import RoleGuard from '../../components/Auth/RoleGuard';
import ClockInOut from '../../components/ERP/HR/ClockInOut';

const ClockPage: React.FC = () => (
  <RoleGuard roles={['admin', 'manager', 'employee']}>
    <MainLayout>
      <ClockInOut />
    </MainLayout>
  </RoleGuard>
);

export default ClockPage;
