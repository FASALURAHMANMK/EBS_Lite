import MainLayout from '../../components/Layout/MainLayout';
import RoleGuard from '../../components/Auth/RoleGuard';
import CashRegister from '../../components/ERP/Accounting/CashRegister';

const CashRegisterPage: React.FC = () => (
  <RoleGuard roles={['admin', 'manager']}>
    <MainLayout>
      <CashRegister />
    </MainLayout>
  </RoleGuard>
);

export default CashRegisterPage;
