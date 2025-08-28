import React from 'react';
import { Customer } from '../../../types';
import { useAuth } from '../../../context/AuthContext';
import {
  User,
  MapPin,
  Phone,
  Mail,
  Edit3,
  Trash2,
  CreditCard,
  History,
  AlertCircle
} from 'lucide-react';

interface CustomerListProps {
  customers: Customer[];
  onEdit: (customer: Customer) => void;
  onCredit: (customer: Customer) => void;
  onHistory: (customer: Customer) => void;
  onSummary: (customer: Customer) => void;
  onDelete: (id: string) => void;
}

const CustomerList: React.FC<CustomerListProps> = ({
  customers,
  onEdit,
  onCredit,
  onHistory,
  onSummary,
  onDelete
}) => {
  const { state: authState } = useAuth();

  const formatCurrency = (amount: number) =>
    new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD'
    }).format(amount);

  if (customers.length === 0) {
    return (
      <div className="text-center py-12">
        <User className="w-12 h-12 text-gray-400 mx-auto mb-4" />
        <p className="text-gray-500 dark:text-gray-400">
          No customers found.
        </p>
      </div>
    );
  }

  return (
    <div className="overflow-x-auto">
      <table className="w-full">
        <thead className="bg-gray-50 dark:bg-gray-800">
          <tr>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Customer
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Contact
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Credit Balance
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Credit Limit
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Loyalty Points
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
              Actions
            </th>
          </tr>
        </thead>
        <tbody className="bg-white dark:bg-gray-900 divide-y divide-gray-200 dark:divide-gray-700">
          {customers.map(customer => (
            <tr
              key={customer._id}
              className="hover:bg-gray-50 dark:hover:bg-gray-800"
            >
              <td className="px-6 py-4 whitespace-nowrap">
                  <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 dark:bg-blue-800 text-blue-800 dark:text-blue-200">
                  {authState.company?.locations?.find(
                    (loc: any) => loc.locationId.toString() === customer.locationId
                  )?.name || 'Unknown'}
                </span>
                <div className="flex items-center mt-2">
                  <div className="w-10 h-10 bg-red-100 dark:bg-red-900/30 rounded-full flex items-center justify-center">
                    <User className="w-5 h-5 text-red-600 dark:text-red-400" />
                  </div>
                  <div className="ml-4">
                    <div className="text-sm font-medium text-gray-900 dark:text-white">
                      {customer.name}
                    </div>
                    {customer.address && (
                      <div className="text-sm text-gray-500 dark:text-gray-400 flex items-center">
                        <MapPin className="w-3 h-3 mr-1" />
                        {customer.address.slice(0, 30)}...
                      </div>
                    )}
                  </div>
                </div>
              </td>
              <td className="px-6 py-4 whitespace-nowrap">
                <div className="space-y-1">
                  <div className="text-sm text-gray-900 dark:text-white flex items-center">
                    <Phone className="w-3 h-3 mr-1" />
                    {customer.phone}
                  </div>
                  {customer.email && (
                    <div className="text-sm text-gray-500 dark:text-gray-400 flex items-center">
                      <Mail className="w-3 h-3 mr-1" />
                      {customer.email}
                    </div>
                  )}
                </div>
              </td>
              <td className="px-6 py-4 whitespace-nowrap">
                <div
                  className={`text-sm font-medium ${
                    customer.credit_balance > 0
                      ? 'text-red-600 dark:text-red-400'
                      : 'text-green-600 dark:text-green-400'
                  }`}
                >
                  {formatCurrency(customer.credit_balance)}
                </div>
              </td>
              <td className="px-6 py-4 whitespace-nowrap">
                <div className="text-sm text-gray-900 dark:text-white">
                  {formatCurrency(customer.creditLimit)}
                </div>
              </td>
              <td className="px-6 py-4 whitespace-nowrap">
                <div className="text-sm text-gray-900 dark:text-white">
                  {customer.loyaltyPoints || 0} pts
                </div>
              </td>
              <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">
                <div className="flex space-x-2">
                  <button
                    onClick={() => onSummary(customer)}
                    className="text-gray-600 hover:text-gray-900 dark:text-gray-400 dark:hover:text-gray-300"
                    title="Summary"
                  >
                    <AlertCircle className="w-4 h-4" />
                  </button>
                  <button
                    onClick={() => onEdit(customer)}
                    className="text-blue-600 hover:text-blue-900 dark:text-blue-400 dark:hover:text-blue-300"
                    title="Edit Customer"
                  >
                    <Edit3 className="w-4 h-4" />
                  </button>
                  <button
                    onClick={() => onCredit(customer)}
                    className="text-green-600 hover:text-green-900 dark:text-green-400 dark:hover:text-green-300"
                    title="Manage Credit"
                  >
                    <CreditCard className="w-4 h-4" />
                  </button>
                  <button
                    onClick={() => onHistory(customer)}
                    className="text-purple-600 hover:text-purple-900 dark:text-purple-400 dark:hover:text-purple-300"
                    title="Credit History"
                  >
                    <History className="w-4 h-4" />
                  </button>
                  <button
                    onClick={() => onDelete(customer._id)}
                    className="text-red-600 hover:text-red-900 dark:text-red-400 dark:hover:text-red-300"
                    title="Delete Customer"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
};

export default CustomerList;
