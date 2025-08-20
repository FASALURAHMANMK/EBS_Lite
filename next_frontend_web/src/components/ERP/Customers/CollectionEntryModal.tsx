import React, { useState } from 'react';
import { Customer } from '../../../types';
import { X, ArrowUpCircle, ArrowDownCircle, Save } from 'lucide-react';

interface Props {
  customer: Customer | null;
  onSubmit: (amount: number, type: 'credit' | 'debit', description: string) => void;
  onClose: () => void;
}

const CollectionEntryModal: React.FC<Props> = ({ customer, onSubmit, onClose }) => {
  const [amount, setAmount] = useState(0);
  const [type, setType] = useState<'credit' | 'debit'>('credit');
  const [description, setDescription] = useState('');

  if (!customer) return null;

  const formatCurrency = (amt: number) =>
    new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD'
    }).format(amt);

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white dark:bg-gray-900 rounded-xl p-6 w-full max-w-md mx-4">
        <div className="flex justify-between items-center mb-4">
          <h3 className="text-lg font-semibold text-gray-800 dark:text-white">Manage Credit</h3>
          <button onClick={onClose} className="p-1 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-full">
            <X className="w-5 h-5 text-gray-500 dark:text-gray-400" />
          </button>
        </div>
        <div className="mb-4 p-4 bg-gray-50 dark:bg-gray-800 rounded-lg">
          <h4 className="font-medium text-gray-800 dark:text-white mb-2">{customer.name}</h4>
          <div className="grid grid-cols-2 gap-4 text-sm">
            <div>
              <span className="text-gray-600 dark:text-gray-400">Current Balance:</span>
              <div className={`${customer.creditBalance > 0 ? 'text-red-600 dark:text-red-400' : 'text-green-600 dark:text-green-400'} font-medium`}>
                {formatCurrency(customer.creditBalance)}
              </div>
            </div>
            <div>
              <span className="text-gray-600 dark:text-gray-400">Credit Limit:</span>
              <div className="font-medium text-gray-800 dark:text-white">
                {formatCurrency(customer.creditLimit)}
              </div>
            </div>
          </div>
        </div>
        <form
          onSubmit={e => {
            e.preventDefault();
            onSubmit(amount, type, description);
          }}
          className="space-y-4"
        >
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Transaction Type</label>
            <div className="grid grid-cols-2 gap-2">
              <button
                type="button"
                onClick={() => setType('credit')}
                className={`p-3 rounded-lg border text-center transition-colors ${type === 'credit' ? 'border-green-500 bg-green-50 dark:bg-green-900/30 text-green-700 dark:text-green-300' : 'border-gray-300 dark:border-gray-600 text-gray-700 dark:text-gray-300'}`}
              >
                <ArrowUpCircle className="w-5 h-5 mx-auto mb-1" />
                <div className="text-sm font-medium">Credit Payment</div>
              </button>
              <button
                type="button"
                onClick={() => setType('debit')}
                className={`p-3 rounded-lg border text-center transition-colors ${type === 'debit' ? 'border-red-500 bg-red-50 dark:bg-red-900/30 text-red-700 dark:text-red-300' : 'border-gray-300 dark:border-gray-600 text-gray-700 dark:text-gray-300'}`}
              >
                <ArrowDownCircle className="w-5 h-5 mx-auto mb-1" />
                <div className="text-sm font-medium">Credit Sale</div>
              </button>
            </div>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Amount *</label>
            <input
              type="number"
              required
              min="0.01"
              step="0.01"
              value={amount}
              onChange={e => setAmount(parseFloat(e.target.value) || 0)}
              className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Description *</label>
            <textarea
              value={description}
              onChange={e => setDescription(e.target.value)}
              rows={2}
              required
              className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white"
            />
          </div>
          <div className="flex space-x-3 pt-4">
            <button
              type="button"
              onClick={onClose}
              className="flex-1 px-4 py-2 border border-gray-300 dark:border-gray-600 text-gray-700 dark:text-gray-300 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-800"
            >
              Cancel
            </button>
            <button
              type="submit"
              className="flex-1 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 flex items-center justify-center space-x-2"
            >
              <Save className="w-4 h-4" />
              <span>Save</span>
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

export default CollectionEntryModal;
