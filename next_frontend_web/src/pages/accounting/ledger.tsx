import MainLayout from '../../components/Layout/MainLayout';
import RoleGuard from '../../components/Auth/RoleGuard';
import LedgerView from '../../components/ERP/Accounting/LedgerView';

const LedgerPage: React.FC = () => (
  <RoleGuard roles={['admin', 'manager']}>
    <MainLayout>
      <LedgerView />
    </MainLayout>
  </RoleGuard>
);

export default LedgerPage;
