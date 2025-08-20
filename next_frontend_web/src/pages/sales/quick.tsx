import MainLayout from '../../components/Layout/MainLayout';
import ClassicPOS from '../../components/ERP/Sales/ClassicPOS';
import RoleGuard from '../../components/Auth/RoleGuard';

const QuickSalesPage: React.FC = () => (
  <RoleGuard roles={['admin', 'manager']}>
    <MainLayout>
      <ClassicPOS />
    </MainLayout>
  </RoleGuard>
);

export default QuickSalesPage;
