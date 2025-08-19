import RoleGuard from '../components/Auth/RoleGuard';
import { CompanyCreatePage } from '../components/Auth/CompanyCreatePage';

const CompanyCreate: React.FC = () => (
  <RoleGuard roles={['admin']}>
    <CompanyCreatePage />
  </RoleGuard>
);

export default CompanyCreate;
