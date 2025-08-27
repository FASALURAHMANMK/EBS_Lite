import React, { useState } from 'react';
import { returns } from '../../../services';
import { Sale } from '../../../types';

interface ReturnItem {
  productId: string;
  productName: string;
  quantity: number;
  selected: boolean;
  returnQty: number;
}

const SaleReturn: React.FC = () => {
  const [invoice, setInvoice] = useState('');
  const [sale, setSale] = useState<Sale | null>(null);
  const [items, setItems] = useState<ReturnItem[]>([]);
  const [loading, setLoading] = useState(false);

  const lookupSale = async () => {
    if (!invoice) return;
    try {
      const { data } = await returns.searchSale(invoice);
      setSale(data);
      setItems(
        data.items.map(i => ({
          productId: i.productId,
          productName: i.productName,
          quantity: i.quantity,
          selected: false,
          returnQty: 0
        }))
      );
    } catch (err) {
      setSale(null);
      setItems([]);
    }
  };

  const toggleSelect = (index: number) => {
    setItems(items.map((item, i) => (i === index ? { ...item, selected: !item.selected } : item)));
  };

  const changeQty = (index: number, qty: number) => {
    setItems(
      items.map((item, i) =>
        i === index ? { ...item, returnQty: Math.min(Math.max(qty, 0), item.quantity) } : item
      )
    );
  };

  const processReturn = async () => {
    if (!sale) return;
    const selectedItems = items
      .filter(i => i.selected && i.returnQty > 0)
      .map(i => ({ productId: i.productId, quantity: i.returnQty }));
    if (selectedItems.length === 0) return;
    setLoading(true);
    try {
      await returns.processReturn(sale._id, { items: selectedItems });
      setSale(null);
      setInvoice('');
      setItems([]);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="space-y-4">
      <div className="flex space-x-2">
        <input
          value={invoice}
          onChange={e => setInvoice(e.target.value)}
          placeholder="Invoice number"
          className="border p-2 flex-1"
        />
        <button onClick={lookupSale} className="px-4 py-2 bg-blue-500 text-white rounded">
          Lookup
        </button>
      </div>

      {sale && (
        <div className="space-y-2">
          {items.map((item, idx) => (
            <div key={item.productId} className="flex items-center space-x-2">
              <input
                type="checkbox"
                checked={item.selected}
                onChange={() => toggleSelect(idx)}
              />
              <span className="flex-1">
                {item.productName} (max {item.quantity})
              </span>
              <input
                type="number"
                min={0}
                max={item.quantity}
                value={item.returnQty}
                onChange={e => changeQty(idx, parseInt(e.target.value, 10) || 0)}
                className="w-20 border p-1"
              />
            </div>
          ))}

          <button
            onClick={processReturn}
            className="px-4 py-2 bg-green-600 text-white rounded"
            disabled={loading}
          >
            {loading ? 'Processing...' : 'Process Return'}
          </button>
        </div>
      )}
    </div>
  );
};

export default SaleReturn;
