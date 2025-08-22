import React, { useEffect, useState } from 'react';
import { accounting } from '../../../services';
import { CashRegister } from '../../../types/accounting';

const CashRegister: React.FC = () => {
  const [registers, setRegisters] = useState<CashRegister[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [openingBalance, setOpeningBalance] = useState(0);
  const [closingBalance, setClosingBalance] = useState(0);

  const refresh = () => {
    accounting
      .getCashRegisters()
      .then((data) => setRegisters(data))
      .catch((err) => setError(err.message));
  };

  useEffect(() => {
    refresh();
  }, []);

  const handleOpen = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      await accounting.openCashRegister({ openingBalance });
      setOpeningBalance(0);
      refresh();
    } catch (err: any) {
      setError(err.message);
    }
  };

  const handleClose = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      await accounting.closeCashRegister({ closingBalance });
      setClosingBalance(0);
      refresh();
    } catch (err: any) {
      setError(err.message);
    }
  };

  return (
    <div className="p-4">
      <h1 className="text-2xl font-bold mb-4">Cash Register</h1>
      {error && <p className="text-red-500">{error}</p>}
      <form onSubmit={handleOpen} className="space-x-2 mb-4">
        <input
          type="number"
          value={openingBalance}
          onChange={(e) => setOpeningBalance(parseFloat(e.target.value))}
          className="border px-2 py-1"
          placeholder="Opening balance"
        />
        <button type="submit" className="bg-green-600 text-white px-3 py-1 rounded">
          Open Register
        </button>
      </form>
      <form onSubmit={handleClose} className="space-x-2 mb-4">
        <input
          type="number"
          value={closingBalance}
          onChange={(e) => setClosingBalance(parseFloat(e.target.value))}
          className="border px-2 py-1"
          placeholder="Closing balance"
        />
        <button type="submit" className="bg-yellow-600 text-white px-3 py-1 rounded">
          Close Register
        </button>
      </form>
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
