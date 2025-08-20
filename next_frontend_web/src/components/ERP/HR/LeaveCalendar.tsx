import React, { useState } from 'react';
import { Calendar } from 'lucide-react';

interface Leave {
  date: string;
  reason: string;
}

const LeaveCalendar: React.FC = () => {
  const [leaves, setLeaves] = useState<Leave[]>([]);
  const [form, setForm] = useState<Leave>({ date: '', reason: '' });

  const addLeave = () => {
    if (form.date) {
      setLeaves(prev => [...prev, form]);
      setForm({ date: '', reason: '' });
    }
  };

  return (
    <div className="p-4">
      <div className="flex items-center space-x-2 mb-4">
        <Calendar className="w-6 h-6" />
        <h2 className="text-xl font-semibold">Leave Calendar</h2>
      </div>
      <div className="flex space-x-2 mb-4">
        <input
          type="date"
          className="border rounded px-2"
          value={form.date}
          onChange={e => setForm({ ...form, date: e.target.value })}
        />
        <input
          type="text"
          placeholder="Reason"
          className="border rounded px-2"
          value={form.reason}
          onChange={e => setForm({ ...form, reason: e.target.value })}
        />
        <button
          onClick={addLeave}
          className="px-4 py-2 bg-blue-500 text-white rounded"
        >
          Add
        </button>
      </div>
      <ul className="space-y-1">
        {leaves.map((l, i) => (
          <li key={i} className="text-sm">
            {l.date}: {l.reason}
          </li>
        ))}
      </ul>
    </div>
  );
};

export default LeaveCalendar;
