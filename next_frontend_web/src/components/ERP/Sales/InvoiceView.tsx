import React, { useEffect, useState } from 'react';
import { useRouter } from 'next/router';
import { getInvoice } from '../../../services/sales';
import { Sale } from '../../../types';

const InvoiceView: React.FC = () => {
  const router = useRouter();
  const { id } = router.query;
  const [invoice, setInvoice] = useState<Sale | null>(null);

  useEffect(() => {
    if (typeof id === 'string') {
      getInvoice(id)
        .then(data => setInvoice(data))
        .catch(() => setInvoice(null));
    }
  }, [id]);

  const shareInvoice = (method: 'print' | 'whatsapp' | 'sms' | 'email') => {
    if (!invoice) return;
    const message = `Invoice ${invoice.saleNumber} Total: ${invoice.total.toFixed(2)}`;
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

  if (!invoice) return <div>Loading...</div>;

  return (
    <div className="p-4 space-y-4">
      <h2 className="text-xl font-semibold">Invoice #{invoice.saleNumber}</h2>
      <ul className="border p-2 divide-y">
        {invoice.items.map(item => (
          <li key={item.productId} className="py-1 flex justify-between">
            <span>
              {item.productName} x{item.quantity}
            </span>
            <span>{(item.unitPrice * item.quantity).toFixed(2)}</span>
          </li>
        ))}
      </ul>
      <div className="font-bold">Total: {invoice.total.toFixed(2)}</div>
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

