import React from 'react';
import ReportGenerator from './ReportGenerator';

const CustomersReport: React.FC = () => (
  <ReportGenerator
    title="Customers Report"
    endpoint="/api/v1/customers"
    filename="customers-report"
    columns={[
      { key: 'name', label: 'Name' },
      { key: 'email', label: 'Email' },
      { key: 'credit_balance', label: 'Credit' }
    ]}
    dateField="createdAt"
  />
);

export default CustomersReport;
