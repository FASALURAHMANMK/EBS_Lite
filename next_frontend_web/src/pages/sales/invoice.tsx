import MainLayout from '../../components/Layout/MainLayout';
import InvoiceView from '../../components/ERP/Sales/InvoiceView';
import RoleGuard from '../../components/Auth/RoleGuard';

const InvoicePage: React.FC = () => (
  <RoleGuard roles={['Admin', 'Manager', 'Sales']}>
    <MainLayout>
      <InvoiceView />
    </MainLayout>
  </RoleGuard>
);

export default InvoicePage;
