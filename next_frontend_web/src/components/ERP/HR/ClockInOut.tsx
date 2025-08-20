import React, { useState } from 'react';
import { Clock } from 'lucide-react';

const ClockInOut: React.FC = () => {
  const [records, setRecords] = useState<{ type: 'in' | 'out'; time: string }[]>([]);

  const handleClock = (type: 'in' | 'out') => {
    const time = new Date().toLocaleString();
    setRecords(prev => [...prev, { type, time }]);
  };

  return (
    <div className="p-4">
      <div className="flex items-center space-x-2 mb-4">
        <Clock className="w-6 h-6" />
        <h2 className="text-xl font-semibold">Clock In/Out</h2>
      </div>
      <div className="space-x-4 mb-4">
        <button
          onClick={() => handleClock('in')}
          className="px-4 py-2 bg-green-500 text-white rounded"
        >
          Clock In
        </button>
        <button
          onClick={() => handleClock('out')}
          className="px-4 py-2 bg-red-500 text-white rounded"
        >
          Clock Out
        </button>
      </div>
      <ul className="space-y-1">
        {records.map((r, i) => (
          <li key={i} className="text-sm">
            {r.type === 'in' ? 'In' : 'Out'} at {r.time}
          </li>
        ))}
      </ul>
    </div>
  );
};

export default ClockInOut;
