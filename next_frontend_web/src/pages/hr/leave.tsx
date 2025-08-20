import MainLayout from '../../components/Layout/MainLayout';
import RoleGuard from '../../components/Auth/RoleGuard';
import LeaveCalendar from '../../components/ERP/HR/LeaveCalendar';

const LeavePage: React.FC = () => (
  <RoleGuard roles={['admin', 'manager', 'employee']}>
    <MainLayout>
      <LeaveCalendar />
    </MainLayout>
  </RoleGuard>
);

export default LeavePage;
