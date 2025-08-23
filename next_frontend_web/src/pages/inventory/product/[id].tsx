import MainLayout from '../../../components/Layout/MainLayout';
import RoleGuard from '../../../components/Auth/RoleGuard';
import ProductDetail from '../../../components/ERP/Inventory/ProductDetail';

const ProductDetailPage: React.FC = () => (
  <RoleGuard roles={['admin', 'manager', 'store']}>
    <MainLayout>
      <ProductDetail />
    </MainLayout>
  </RoleGuard>
);

export default ProductDetailPage;
