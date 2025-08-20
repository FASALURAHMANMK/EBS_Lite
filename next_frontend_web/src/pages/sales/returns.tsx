import MainLayout from '../../components/Layout/MainLayout';
import ModernPOS from '../../components/ERP/Sales/ModernPOS';
import RoleGuard from '../../components/Auth/RoleGuard';

const ReturnsPage: React.FC = () => (
  <RoleGuard roles={['admin', 'manager']}>
    <MainLayout>
      <ModernPOS mode="return" />
    </MainLayout>
  </RoleGuard>
);

export default ReturnsPage;
