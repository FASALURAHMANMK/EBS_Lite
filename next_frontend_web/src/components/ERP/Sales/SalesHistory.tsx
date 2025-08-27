import React, { useState, useEffect } from 'react';
import { useAppState } from '../../../context/MainContext';
import { getSalesHistory, exportSalesHistory } from '../../../services/sales';
import { Sale } from '../../../types';

const SalesHistory: React.FC = () => {
  const { customers, products } = useAppState(s => ({
    customers: s.customers,
    products: s.products,
  }));
  const [filters, setFilters] = useState({
    startDate: '',
    endDate: '',
    customerId: '',
    productId: '',
    paymentMethod: '',
  });
  const [data, setData] = useState<Sale[]>([]);

  const loadData = async () => {
    try {
      const res = await getSalesHistory(filters);
      setData(res);
    } catch (err) {
      console.error('Failed to load sales history', err);
    }
  };

  useEffect(() => {
    loadData();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const handleExport = async () => {
    try {
      const blob = await exportSalesHistory(filters);
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = 'sales-history.csv';
      a.click();
      window.URL.revokeObjectURL(url);
    } catch (err) {
      console.error('Failed to export sales history', err);
    }
  };

  return (
    <div className="p-4">
      <h2 className="text-xl font-semibold mb-4">Sales History</h2>
      <div className="flex flex-wrap gap-4 mb-4">
        <div>
          <label className="block text-sm mb-1">From</label>
          <input
            type="date"
            value={filters.startDate}
            onChange={e => setFilters({ ...filters, startDate: e.target.value })}
            className="border px-2 py-1"
          />
        </div>
        <div>
          <label className="block text-sm mb-1">To</label>
          <input
            type="date"
            value={filters.endDate}
            onChange={e => setFilters({ ...filters, endDate: e.target.value })}
            className="border px-2 py-1"
          />
        </div>
        <div>
          <label className="block text-sm mb-1">Customer</label>
          <select
            value={filters.customerId}
            onChange={e => setFilters({ ...filters, customerId: e.target.value })}
            className="border px-2 py-1"
          >
            <option value="">All</option>
            {customers.map(c => (
              <option key={c._id} value={c._id}>
                {c.name}
              </option>
            ))}
          </select>
        </div>
        <div>
          <label className="block text-sm mb-1">Product</label>
          <select
            value={filters.productId}
            onChange={e => setFilters({ ...filters, productId: e.target.value })}
            className="border px-2 py-1"
          >
            <option value="">All</option>
            {products.map(p => (
              <option key={p._id} value={p._id}>
                {p.name}
              </option>
            ))}
          </select>
        </div>
        <div>
          <label className="block text-sm mb-1">Payment</label>
          <select
            value={filters.paymentMethod}
            onChange={e =>
              setFilters({ ...filters, paymentMethod: e.target.value })
            }
            className="border px-2 py-1"
          >
            <option value="">All</option>
            <option value="cash">Cash</option>
            <option value="card">Card</option>
            <option value="upi">UPI</option>
            <option value="netbanking">Net Banking</option>
            <option value="credit">Credit</option>
          </select>
        </div>
        <button
          onClick={loadData}
          className="self-end bg-blue-500 text-white px-4 py-2 rounded"
        >
          Filter
        </button>
        <button
          onClick={handleExport}
          className="self-end bg-green-600 text-white px-4 py-2 rounded"
        >
          Export
        </button>
      </div>
      <table className="w-full text-left border">
        <thead>
          <tr>
            <th className="border px-2 py-1">Sale #</th>
            <th className="border px-2 py-1">Date</th>
            <th className="border px-2 py-1">Total</th>
          </tr>
        </thead>
        <tbody>
          {data.map(sale => (
            <tr key={sale._id}>
              <td className="border px-2 py-1">{sale.saleNumber}</td>
              <td className="border px-2 py-1">
                {sale.date ? new Date(sale.date).toLocaleString() : ''}
              </td>
              <td className="border px-2 py-1">{sale.total.toFixed(2)}</td>
            </tr>
          ))}
          {data.length === 0 && (
            <tr>
              <td className="border px-2 py-1 text-center" colSpan={3}>
                No sales found.
              </td>
            </tr>
          )}
        </tbody>
      </table>
    </div>
  );
};

export default SalesHistory;
