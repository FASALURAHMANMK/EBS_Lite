import React, { useEffect, useState } from 'react';
import { useAppState } from '../../../context/MainContext';
import { inventory } from '../../../services';

const TransferRequest: React.FC = () => {
  const state = useAppState(s => s);
  const [fromLocation, setFromLocation] = useState(state.currentLocationId || '');
  const [toLocation, setToLocation] = useState('');
  const [productId, setProductId] = useState('');
  const [quantity, setQuantity] = useState(0);
  const [transfers, setTransfers] = useState<any[]>([]);

  useEffect(() => {
    inventory.getTransfers().then(setTransfers).catch(() => {});
  }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      await inventory.createTransfer({
        fromLocationId: fromLocation,
        toLocationId: toLocation,
        items: [{ productId, quantity }],
      });
      setProductId('');
      setQuantity(0);
      inventory.getTransfers().then(setTransfers).catch(() => {});
    } catch (err) {
      console.error(err);
    }
  };

  return (
    <div className="p-4 max-w-xl">
      <h1 className="text-2xl font-bold mb-4">Transfer Request</h1>
      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label className="block text-sm mb-1">From Location</label>
          <input
            className="w-full border px-2 py-1"
            value={fromLocation}
            onChange={e => setFromLocation(e.target.value)}
          />
        </div>
        <div>
          <label className="block text-sm mb-1">To Location</label>
          <input
            className="w-full border px-2 py-1"
            value={toLocation}
            onChange={e => setToLocation(e.target.value)}
          />
        </div>
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
          <label className="block text-sm mb-1">Quantity</label>
          <input
            type="number"
            className="w-full border px-2 py-1"
            value={quantity}
            onChange={e => setQuantity(parseFloat(e.target.value))}
          />
        </div>
        <button className="px-4 py-2 bg-blue-600 text-white rounded" type="submit">Request Transfer</button>
      </form>
      <ul className="mt-4 space-y-2">
        {transfers.map((t, idx) => (
          <li key={idx} className="border p-2 rounded">
            <div>From: {t.fromLocationId}</div>
            <div>To: {t.toLocationId}</div>
            <div>
              Items:{' '}
              {t.items?.map((i: any) => `${i.productId} (${i.quantity})`).join(', ')}
            </div>
            {t.reference && <div>Ref: {t.reference}</div>}
          </li>
        ))}
      </ul>
    </div>
  );
};

export default TransferRequest;
