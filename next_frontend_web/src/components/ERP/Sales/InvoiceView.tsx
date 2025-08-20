import React from 'react';
import { useAppState } from '../../../context/MainContext';

const InvoiceView: React.FC = () => {
  const state = useAppState(s => s);
  const total = state.cart.reduce(
    (sum, item) => sum + item.product.price * item.quantity,
    0
  );

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

  return (
    <div className="p-4 space-y-4">
      <h2 className="text-xl font-semibold">Invoice</h2>
      <ul className="border p-2 divide-y">
        {state.cart.map(item => (
          <li key={item.product._id} className="py-1 flex justify-between">
            <span>
              {item.product.name} x{item.quantity}
            </span>
            <span>{(item.product.price * item.quantity).toFixed(2)}</span>
          </li>
        ))}
      </ul>
      <div className="font-bold">Total: {total.toFixed(2)}</div>
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
    </div>
  );
};

export default InvoiceView;
