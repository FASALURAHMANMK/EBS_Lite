import React from 'react';
import ReportGenerator from './ReportGenerator';

const SalesReport: React.FC = () => (
  <ReportGenerator
    title="Sales Report"
    endpoint="/api/v1/sales"
    filename="sales-report"
    columns={[
      { key: 'saleNumber', label: 'Sale #' },
      { key: 'date', label: 'Date' },
      { key: 'total', label: 'Total' }
    ]}
    dateField="date"
  />
);

export default SalesReport;
