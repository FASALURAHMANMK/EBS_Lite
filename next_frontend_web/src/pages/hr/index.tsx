import MainLayout from '../../components/Layout/MainLayout';
import RoleGuard from '../../components/Auth/RoleGuard';
import Link from 'next/link';

const HRDashboard: React.FC = () => (
  <RoleGuard roles={['Admin', 'HR']}>
    <MainLayout>
      <div className="p-6 space-y-4">
        <h1 className="text-2xl font-bold">Human Resources</h1>
        <ul className="list-disc pl-6 space-y-1">
          <li><Link href="/hr/clock" className="text-blue-600 hover:underline">Clock In/Out</Link></li>
          <li><Link href="/hr/leave" className="text-blue-600 hover:underline">Leave Calendar</Link></li>
          <li><Link href="/hr/payroll" className="text-blue-600 hover:underline">Salary Processing</Link></li>
        </ul>
      </div>
    </MainLayout>
  </RoleGuard>
);

export default HRDashboard;
