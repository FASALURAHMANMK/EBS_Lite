import React from 'react';
import ReportGenerator from './ReportGenerator';

const InventoryReport: React.FC = () => (
  <ReportGenerator
    title="Inventory Report"
    endpoint="/api/v1/products"
    filename="inventory-report"
    columns={[
      { key: 'sku', label: 'SKU' },
      { key: 'name', label: 'Product' },
      { key: 'stock', label: 'Stock' },
      { key: 'price', label: 'Price' }
    ]}
    dateField="updatedAt"
  />
);

export default InventoryReport;
