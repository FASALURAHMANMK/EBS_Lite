import MainLayout from '../../components/Layout/MainLayout';
import RoleGuard from '../../components/Auth/RoleGuard';
import VoucherEntry from '../../components/ERP/Accounting/VoucherEntry';

const VoucherEntryPage: React.FC = () => (
  <RoleGuard roles={['admin', 'manager']}>
    <MainLayout>
      <VoucherEntry />
    </MainLayout>
  </RoleGuard>
);

export default VoucherEntryPage;
