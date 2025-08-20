import React from 'react';

export interface LedgerEntry {
  id: number;
  employee: string;
  amount: number;
  date: string;
}

interface PayrollLedgerProps {
  entries: LedgerEntry[];
}

const PayrollLedger: React.FC<PayrollLedgerProps> = ({ entries }) => (
  <div className="mt-6">
    <h3 className="text-lg font-semibold mb-2">Payroll Ledger</h3>
    <table className="min-w-full border">
      <thead>
        <tr className="bg-gray-100">
          <th className="px-2 py-1 border">Date</th>
          <th className="px-2 py-1 border">Employee</th>
          <th className="px-2 py-1 border">Amount</th>
        </tr>
      </thead>
      <tbody>
        {entries.map(entry => (
          <tr key={entry.id}>
            <td className="px-2 py-1 border">{entry.date}</td>
            <td className="px-2 py-1 border">{entry.employee}</td>
            <td className="px-2 py-1 border">${entry.amount.toFixed(2)}</td>
          </tr>
        ))}
      </tbody>
    </table>
  </div>
);

export default PayrollLedger;
