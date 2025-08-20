import React from 'react';
import { useAppState } from '../../../context/MainContext';

const SalesHistory: React.FC = () => {
  const state = useAppState(s => s);

  return (
    <div className="p-4">
      <h2 className="text-xl font-semibold mb-4">Sales History</h2>
      <table className="w-full text-left border">
        <thead>
          <tr>
            <th className="border px-2 py-1">Sale #</th>
            <th className="border px-2 py-1">Date</th>
            <th className="border px-2 py-1">Total</th>
          </tr>
        </thead>
        <tbody>
          {state.recentSales.map(sale => (
            <tr key={sale._id}>
              <td className="border px-2 py-1">{sale.saleNumber}</td>
              <td className="border px-2 py-1">{sale.date ? new Date(sale.date).toLocaleString() : ''}</td>
              <td className="border px-2 py-1">{sale.total.toFixed(2)}</td>
            </tr>
          ))}
          {state.recentSales.length === 0 && (
            <tr>
              <td className="border px-2 py-1 text-center" colSpan={3}>
                No sales yet.
              </td>
            </tr>
          )}
        </tbody>
      </table>
    </div>
  );
};

export default SalesHistory;
