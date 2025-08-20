import React, { useState } from 'react';
import { useAppState, useAppDispatch, useAppActions } from '../../../context/MainContext';
import { Product } from '../../../types';
import { X } from 'lucide-react';

interface POSBaseProps {
  variant: 'classic' | 'modern';
  mode?: 'sale' | 'return';
}

const POSBase: React.FC<POSBaseProps> = ({ variant, mode = 'sale' }) => {
  const state = useAppState(s => s);
  const dispatch = useAppDispatch();
  const { searchProducts, createCustomer } = useAppActions();

  const [barcode, setBarcode] = useState('');
  const [discount, setDiscount] = useState(0);
  const [tax, setTax] = useState(0);
  const [loyalty, setLoyalty] = useState(0);
  const [promo, setPromo] = useState('');
  const [selectedCustomer, setSelectedCustomer] = useState('');
  const [showCustomerModal, setShowCustomerModal] = useState(false);
  const [newCustomer, setNewCustomer] = useState({ name: '', phone: '' });

  const handleBarcodeKey = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter' && barcode.trim()) {
      const results = searchProducts(barcode.trim());
      if (results.length > 0) {
        dispatch({ type: 'ADD_TO_CART', payload: results[0] as Product });
      }
      setBarcode('');
    }
  };

  const subtotal = state.cart.reduce(
    (sum, item) => sum + item.product.price * item.quantity,
    0
  );
  const discountAmount = subtotal * (discount / 100);
  const promoAmount = promo === 'PROMO10' ? subtotal * 0.1 : 0;
  const loyaltyAmount = loyalty;
  const taxedBase = subtotal - discountAmount - promoAmount - loyaltyAmount;
  const taxAmount = taxedBase * (tax / 100);
  const total = mode === 'return' ? -(taxedBase + taxAmount) : taxedBase + taxAmount;

  const shareInvoice = (method: 'print' | 'whatsapp' | 'sms' | 'email') => {
    const message = `Invoice Total: ${total.toFixed(2)}`;
    switch (method) {
      case 'print':
        window.print();
        break;
      case 'whatsapp':
        window.open(`https://wa.me/?text=${encodeURIComponent(message)}`);
        break;
      case 'sms':
        window.open(`sms:?body=${encodeURIComponent(message)}`);
        break;
      case 'email':
        window.location.href = `mailto:?subject=Invoice&body=${encodeURIComponent(message)}`;
        break;
    }
  };

  const handleQuickAdd = async (e: React.FormEvent) => {
    e.preventDefault();
    const customer = await createCustomer({
      name: newCustomer.name,
      phone: newCustomer.phone,
      email: '',
      address: '',
      locationId: state.currentLocationId || '',
      creditLimit: 0,
      notes: '',
      creditBalance: 0,
      loyaltyPoints: 0,
      isActive: true
    });
    setSelectedCustomer(customer._id);
    setShowCustomerModal(false);
    setNewCustomer({ name: '', phone: '' });
  };

  return (
    <div
      className={
        variant === 'modern'
          ? 'p-4 space-y-4 bg-gray-50 dark:bg-gray-900 rounded-lg'
          : 'space-y-4'
      }
    >
      <div className="flex items-center space-x-2">
        <select
          value={selectedCustomer}
          onChange={e => setSelectedCustomer(e.target.value)}
          className="border p-2 flex-1"
        >
          <option value="">Walk-in Customer</option>
          {state.customers.map(c => (
            <option key={c._id} value={c._id}>
              {c.name}
            </option>
          ))}
        </select>
        <button
          onClick={() => setShowCustomerModal(true)}
          className="px-3 py-2 bg-red-600 text-white rounded"
        >
          New
        </button>
      </div>

      <div>
        <input
          value={barcode}
          onChange={e => setBarcode(e.target.value)}
          onKeyDown={handleBarcodeKey}
          placeholder="Scan barcode"
          className="border p-2 w-full"
        />
      </div>

      <div className="space-y-2">
        <input
          type="number"
          value={discount}
          onChange={e => setDiscount(parseFloat(e.target.value) || 0)}
          placeholder="Discount %"
          className="border p-2 w-full"
        />
        <input
          type="number"
          value={tax}
          onChange={e => setTax(parseFloat(e.target.value) || 0)}
          placeholder="Tax %"
          className="border p-2 w-full"
        />
        <input
          type="number"
          value={loyalty}
          onChange={e => setLoyalty(parseFloat(e.target.value) || 0)}
          placeholder="Loyalty points"
          className="border p-2 w-full"
        />
        <input
          value={promo}
          onChange={e => setPromo(e.target.value)}
          placeholder="Promotion code"
          className="border p-2 w-full"
        />
      </div>

      <div className="border-t pt-2 space-y-1">
        <div>Subtotal: {subtotal.toFixed(2)}</div>
        <div>Discount: -{discountAmount.toFixed(2)}</div>
        {promoAmount > 0 && <div>Promotion: -{promoAmount.toFixed(2)}</div>}
        {loyaltyAmount > 0 && <div>Loyalty: -{loyaltyAmount.toFixed(2)}</div>}
        <div>Tax: {taxAmount.toFixed(2)}</div>
        <div className="font-bold">Total: {total.toFixed(2)}</div>
      </div>

      <div className="flex flex-wrap gap-2">
        <button
          onClick={() => shareInvoice('print')}
          className="px-3 py-2 bg-gray-200 rounded"
        >
          Print
        </button>
        <button
          onClick={() => shareInvoice('whatsapp')}
          className="px-3 py-2 bg-green-500 text-white rounded"
        >
          WhatsApp
        </button>
        <button
          onClick={() => shareInvoice('sms')}
          className="px-3 py-2 bg-blue-500 text-white rounded"
        >
          SMS
        </button>
        <button
          onClick={() => shareInvoice('email')}
          className="px-3 py-2 bg-indigo-500 text-white rounded"
        >
          Email
        </button>
      </div>

      {showCustomerModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white dark:bg-gray-900 p-4 rounded-lg w-full max-w-sm">
            <div className="flex justify-between items-center mb-4">
              <h3 className="text-lg font-semibold text-gray-800 dark:text-white">New Customer</h3>
              <button
                onClick={() => setShowCustomerModal(false)}
                className="p-1 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-full"
              >
                <X className="w-5 h-5 text-gray-500 dark:text-gray-400" />
              </button>
            </div>
            <form onSubmit={handleQuickAdd} className="space-y-4">
              <div>
                <input
                  type="text"
                  required
                  placeholder="Customer Name"
                  value={newCustomer.name}
                  onChange={e => setNewCustomer(prev => ({ ...prev, name: e.target.value }))}
                  className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white"
                />
              </div>
              <div>
                <input
                  type="tel"
                  required
                  placeholder="Phone"
                  value={newCustomer.phone}
                  onChange={e => setNewCustomer(prev => ({ ...prev, phone: e.target.value }))}
                  className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white"
                />
              </div>
              <div className="flex space-x-3 pt-2">
                <button
                  type="button"
                  onClick={() => setShowCustomerModal(false)}
                  className="flex-1 px-4 py-2 border border-gray-300 dark:border-gray-600 text-gray-700 dark:text-gray-300 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-800"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="flex-1 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700"
                >
                  Save
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

export default POSBase;
