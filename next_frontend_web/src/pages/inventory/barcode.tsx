import MainLayout from '../../components/Layout/MainLayout';
import RoleGuard from '../../components/Auth/RoleGuard';
import BarcodeLabelPrinter from '../../components/ERP/Inventory/BarcodeLabelPrinter';

const BarcodePage: React.FC = () => (
  <RoleGuard roles={['admin', 'manager']}>
    <MainLayout>
      <BarcodeLabelPrinter />
    </MainLayout>
  </RoleGuard>
);

export default BarcodePage;
