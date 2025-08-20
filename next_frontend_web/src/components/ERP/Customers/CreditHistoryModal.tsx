import React from 'react';
import { CreditTransaction, Customer } from '../../../types';
import { X, ArrowUpCircle, ArrowDownCircle } from 'lucide-react';

interface Props {
  customer: Customer | null;
  history: CreditTransaction[];
  onClose: () => void;
}

const CreditHistoryModal: React.FC<Props> = ({ customer, history, onClose }) => {
  if (!customer) return null;

  const formatCurrency = (amount: number) =>
    new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD'
    }).format(amount);

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white dark:bg-gray-900 rounded-xl p-6 w-full max-w-lg mx-4">
        <div className="flex justify-between items-center mb-4">
          <h3 className="text-lg font-semibold text-gray-800 dark:text-white">
            Credit History - {customer.name}
          </h3>
          <button onClick={onClose} className="p-1 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-full">
            <X className="w-5 h-5 text-gray-500 dark:text-gray-400" />
          </button>
        </div>
        {history.length === 0 ? (
          <div className="text-center py-8 text-gray-500 dark:text-gray-400">
            No credit history available.
          </div>
        ) : (
          <div className="max-h-96 overflow-y-auto">
            <table className="w-full text-sm">
              <thead className="bg-gray-50 dark:bg-gray-800">
                <tr>
                  <th className="px-4 py-2 text-left">Date</th>
                  <th className="px-4 py-2 text-left">Type</th>
                  <th className="px-4 py-2 text-right">Amount</th>
                  <th className="px-4 py-2 text-left">Description</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200 dark:divide-gray-700">
                {history.map(tx => (
                  <tr key={tx._id}>
                    <td className="px-4 py-2">{new Date(tx.date).toLocaleDateString()}</td>
                    <td className="px-4 py-2">
                      {tx.type === 'credit' ? (
                        <span className="inline-flex items-center text-green-600 dark:text-green-400">
                          <ArrowUpCircle className="w-4 h-4 mr-1" /> Credit
                        </span>
                      ) : (
                        <span className="inline-flex items-center text-red-600 dark:text-red-400">
                          <ArrowDownCircle className="w-4 h-4 mr-1" /> Debit
                        </span>
                      )}
                    </td>
                    <td className="px-4 py-2 text-right">{formatCurrency(tx.amount)}</td>
                    <td className="px-4 py-2">{tx.description}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
};

export default CreditHistoryModal;
