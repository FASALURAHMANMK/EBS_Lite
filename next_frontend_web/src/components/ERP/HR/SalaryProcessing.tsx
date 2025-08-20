import React, { useState } from 'react';
import { DollarSign } from 'lucide-react';
import PayrollLedger, { LedgerEntry } from './PayrollLedger';

const SalaryProcessing: React.FC = () => {
  const [entries, setEntries] = useState<LedgerEntry[]>([]);
  const [form, setForm] = useState({ employee: '', amount: '' });

  const processSalary = () => {
    if (form.employee && form.amount) {
      const newEntry: LedgerEntry = {
        id: entries.length + 1,
        employee: form.employee,
        amount: parseFloat(form.amount),
        date: new Date().toLocaleDateString(),
      };
      setEntries(prev => [...prev, newEntry]);
      setForm({ employee: '', amount: '' });
    }
  };

  return (
    <div className="p-4">
      <div className="flex items-center space-x-2 mb-4">
        <DollarSign className="w-6 h-6" />
        <h2 className="text-xl font-semibold">Salary Processing</h2>
      </div>
      <div className="flex space-x-2 mb-4">
        <input
          type="text"
          placeholder="Employee"
          className="border rounded px-2"
          value={form.employee}
          onChange={e => setForm({ ...form, employee: e.target.value })}
        />
        <input
          type="number"
          placeholder="Amount"
          className="border rounded px-2"
          value={form.amount}
          onChange={e => setForm({ ...form, amount: e.target.value })}
        />
        <button
          onClick={processSalary}
          className="px-4 py-2 bg-green-600 text-white rounded"
        >
          Process
        </button>
      </div>
      <PayrollLedger entries={entries} />
    </div>
  );
};

export default SalaryProcessing;
