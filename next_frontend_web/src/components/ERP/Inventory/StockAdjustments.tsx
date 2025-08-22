import React, { useEffect, useState } from 'react';
import { useAppState } from '../../../context/MainContext';
import { inventory } from '../../../services';

const StockAdjustments: React.FC = () => {
  const state = useAppState(s => s);
  const [productId, setProductId] = useState('');
  const [locationId, setLocationId] = useState(state.currentLocationId || '');
  const [quantity, setQuantity] = useState(0);
  const [reason, setReason] = useState('');
  const [adjustments, setAdjustments] = useState<any[]>([]);

  useEffect(() => {
    inventory.getStockAdjustments().then(setAdjustments).catch(() => {});
  }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      await inventory.adjustStock({ productId, locationId, quantity, reason });
      setProductId('');
      setQuantity(0);
      setReason('');
      inventory.getStockAdjustments().then(setAdjustments).catch(() => {});
    } catch (err) {
      console.error(err);
    }
  };

  return (
    <div className="p-4 max-w-xl">
      <h1 className="text-2xl font-bold mb-4">Stock Adjustment</h1>
      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label className="block text-sm mb-1">Product</label>
          <select value={productId} onChange={e => setProductId(e.target.value)} className="w-full border px-2 py-1">
            <option value="">Select product</option>
            {state.products.map(p => (
              <option key={p._id} value={p._id}>{p.name}</option>
            ))}
          </select>
        </div>
        <div>
          <label className="block text-sm mb-1">Location</label>
          <input
            className="w-full border px-2 py-1"
            value={locationId}
            onChange={e => setLocationId(e.target.value)}
          />
        </div>
        <div>
          <label className="block text-sm mb-1">Quantity</label>
          <input
            type="number"
            className="w-full border px-2 py-1"
            value={quantity}
            onChange={e => setQuantity(parseFloat(e.target.value))}
          />
        </div>
        <div>
          <label className="block text-sm mb-1">Reason</label>
          <input
            className="w-full border px-2 py-1"
            value={reason}
            onChange={e => setReason(e.target.value)}
          />
        </div>
        <button className="px-4 py-2 bg-blue-600 text-white rounded" type="submit">Adjust</button>
      </form>
      <ul className="mt-4 space-y-2">
        {adjustments.map((a, idx) => (
          <li key={idx} className="border p-2 rounded">
            <div>Product: {a.productId}</div>
            <div>Location: {a.locationId}</div>
            <div>Quantity: {a.quantity}</div>
            {a.reason && <div>Reason: {a.reason}</div>}
          </li>
        ))}
      </ul>
    </div>
  );
};

export default StockAdjustments;
