import React, { useState } from 'react';
import { useAppState, useAppDispatch, useAppActions } from '../../../context/MainContext';
import { Product } from '../../../types';

interface POSBaseProps {
  variant: 'classic' | 'modern';
  mode?: 'sale' | 'return';
}

const POSBase: React.FC<POSBaseProps> = ({ variant, mode = 'sale' }) => {
  const state = useAppState(s => s);
  const dispatch = useAppDispatch();
  const { searchProducts } = useAppActions();

  const [barcode, setBarcode] = useState('');
  const [discount, setDiscount] = useState(0);
  const [tax, setTax] = useState(0);
  const [loyalty, setLoyalty] = useState(0);
  const [promo, setPromo] = useState('');

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

  return (
    <div
      className={
        variant === 'modern'
          ? 'p-4 space-y-4 bg-gray-50 dark:bg-gray-900 rounded-lg'
          : 'space-y-4'
      }
    >
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
    </div>
  );
};

export default POSBase;
