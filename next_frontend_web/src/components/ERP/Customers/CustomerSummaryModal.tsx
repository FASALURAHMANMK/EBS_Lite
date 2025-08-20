import React from 'react';
import { Customer } from '../../../types';
import { X, Phone, Mail, MapPin, CreditCard, Wallet } from 'lucide-react';

interface Props {
  customer: Customer | null;
  onClose: () => void;
}

const CustomerSummaryModal: React.FC<Props> = ({ customer, onClose }) => {
  if (!customer) return null;

  const formatCurrency = (amount: number) =>
    new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD'
    }).format(amount);

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white dark:bg-gray-900 rounded-xl p-6 w-full max-w-md mx-4">
        <div className="flex justify-between items-center mb-4">
          <h3 className="text-lg font-semibold text-gray-800 dark:text-white">Customer Summary</h3>
          <button onClick={onClose} className="p-1 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-full">
            <X className="w-5 h-5 text-gray-500 dark:text-gray-400" />
          </button>
        </div>
        <div className="space-y-3 text-sm">
          <div className="font-medium text-gray-900 dark:text-white">{customer.name}</div>
          <div className="flex items-center text-gray-700 dark:text-gray-300">
            <Phone className="w-4 h-4 mr-2" />
            {customer.phone}
          </div>
          {customer.email && (
            <div className="flex items-center text-gray-700 dark:text-gray-300">
              <Mail className="w-4 h-4 mr-2" />
              {customer.email}
            </div>
          )}
          {customer.address && (
            <div className="flex items-center text-gray-700 dark:text-gray-300">
              <MapPin className="w-4 h-4 mr-2" />
              {customer.address}
            </div>
          )}
          <div className="flex items-center text-gray-700 dark:text-gray-300">
            <CreditCard className="w-4 h-4 mr-2" />
            Credit Limit: {formatCurrency(customer.creditLimit)}
          </div>
          <div className="flex items-center text-gray-700 dark:text-gray-300">
            <Wallet className="w-4 h-4 mr-2" />
            Balance: {formatCurrency(customer.creditBalance)}
          </div>
        </div>
      </div>
    </div>
  );
};

export default CustomerSummaryModal;
