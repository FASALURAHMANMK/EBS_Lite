import React, { useEffect, useState } from 'react';
import { accounting } from '../../../services';
import { CashRegister } from '../../../types/accounting';

const CashRegister: React.FC = () => {
  const [registers, setRegisters] = useState<CashRegister[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    accounting
      .getCashRegisters()
      .then((data) => setRegisters(data))
      .catch((err) => setError(err.message));
  }, []);

  return (
    <div className="p-4">
      <h1 className="text-2xl font-bold mb-4">Cash Register</h1>
      {error && <p className="text-red-500">{error}</p>}
      <ul className="space-y-2">
        {registers.map((r) => (
          <li key={r.id} className="border p-2 rounded">
            <div>Opened: {new Date(r.openedAt).toLocaleString()}</div>
            {r.closedAt && (
              <div>Closed: {new Date(r.closedAt).toLocaleString()}</div>
            )}
            <div>Opening Balance: {r.openingBalance}</div>
            {r.closingBalance !== undefined && (
              <div>Closing Balance: {r.closingBalance}</div>
            )}
          </li>
        ))}
      </ul>
    </div>
  );
};

export default CashRegister;
