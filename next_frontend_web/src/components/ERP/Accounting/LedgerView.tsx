import React, { useEffect, useState } from 'react';
import { accounting } from '../../../services';
import { LedgerEntry, AccountBalance } from '../../../types/accounting';

const LedgerView: React.FC = () => {
  const [balances, setBalances] = useState<AccountBalance[]>([]);
  const [entries, setEntries] = useState<LedgerEntry[]>([]);

  useEffect(() => {
    accounting.getLedgerBalances().then((data) => setBalances(data));
  }, []);

  const loadEntries = (accountId: number) => {
    accounting
      .getLedgerEntries({ accountId })
      .then((data) => setEntries(data));
  };

  return (
    <div className="p-4">
      <h1 className="text-2xl font-bold mb-4">Ledger</h1>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div>
          <h2 className="font-semibold mb-2">Accounts</h2>
          <ul className="space-y-2">
            {balances.map((b) => (
              <li
                key={b.accountId}
                className="border p-2 rounded cursor-pointer"
                onClick={() => loadEntries(b.accountId)}
              >
                {b.accountName}: {b.balance}
              </li>
            ))}
          </ul>
        </div>
        <div>
          <h2 className="font-semibold mb-2">Entries</h2>
          <ul className="space-y-2">
            {entries.map((e) => (
              <li key={e.id} className="border p-2 rounded">
                <div>{new Date(e.entryDate).toLocaleDateString()}</div>
                <div>
                  Debit: {e.debit} Credit: {e.credit} Balance: {e.balance}
                </div>
              </li>
            ))}
          </ul>
        </div>
      </div>
    </div>
  );
};

export default LedgerView;
