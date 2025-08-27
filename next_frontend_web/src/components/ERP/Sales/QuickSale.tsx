import React, { useState } from 'react';
import { createQuickSale } from '../../../services/sales';

export interface QuickSaleItem {
  price: number;
  quantity: number;
}

interface QuickSaleProps {
  items: QuickSaleItem[];
  onChange: (items: QuickSaleItem[]) => void;
}

const QuickSale: React.FC<QuickSaleProps> = ({ items, onChange }) => {
  const [price, setPrice] = useState('');
  const [quantity, setQuantity] = useState('');
  const [loading, setLoading] = useState(false);

  const addItem = () => {
    const p = parseFloat(price);
    const q = parseFloat(quantity);
    if (p > 0 && q > 0) {
      onChange([...items, { price: p, quantity: q }]);
      setPrice('');
      setQuantity('');
    }
  };

  const removeItem = (index: number) => {
    onChange(items.filter((_, i) => i !== index));
  };

  const total = items.reduce((sum, item) => sum + item.price * item.quantity, 0);

  const handleSubmit = async () => {
    if (items.length === 0) return;
    setLoading(true);
    try {
      await createQuickSale({ items, total });
      onChange([]);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="space-y-4">
      <div className="flex space-x-2">
        <input
          type="number"
          value={price}
          onChange={e => setPrice(e.target.value)}
          placeholder="Price"
          className="border p-2 flex-1"
        />
        <input
          type="number"
          value={quantity}
          onChange={e => setQuantity(e.target.value)}
          placeholder="Qty"
          className="border p-2 flex-1"
        />
        <button
          onClick={addItem}
          className="px-4 py-2 bg-blue-500 text-white rounded"
        >
          Add
        </button>
      </div>

      <div className="space-y-2">
        {items.map((item, idx) => (
          <div
            key={idx}
            className="flex justify-between items-center border p-2 rounded"
          >
            <span>
              {item.quantity} x {item.price.toFixed(2)}
            </span>
            <span>{(item.quantity * item.price).toFixed(2)}</span>
            <button
              onClick={() => removeItem(idx)}
              className="text-red-500"
            >
              Remove
            </button>
          </div>
        ))}
      </div>

      <div className="font-bold">Total: {total.toFixed(2)}</div>

      <button
        onClick={handleSubmit}
        className="px-4 py-2 bg-green-600 text-white rounded"
        disabled={items.length === 0 || loading}
      >
        {loading ? 'Saving...' : 'Submit'}
      </button>
    </div>
  );
};

export default QuickSale;
