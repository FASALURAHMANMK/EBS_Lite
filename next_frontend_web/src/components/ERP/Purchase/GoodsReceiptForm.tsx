import React, { useState } from 'react';
import { purchases } from '../../../services';

const GoodsReceiptForm: React.FC = () => {
  const [form, setForm] = useState({
    purchaseId: '',
    purchaseDetailId: '',
    receivedQuantity: 1,
  });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      await purchases.recordGoodsReceipt({
        purchaseId: Number(form.purchaseId),
        items: [
          {
            purchaseDetailId: Number(form.purchaseDetailId),
            receivedQuantity: Number(form.receivedQuantity),
          },
        ],
      });
      setForm({ purchaseId: '', purchaseDetailId: '', receivedQuantity: 1 });
    } catch (err) {
      console.error(err);
    }
  };

  return (
    <form onSubmit={handleSubmit} className="p-4 space-y-2">
      <h2 className="text-xl font-semibold">Goods Receipt Note</h2>
      <input
        className="border p-2 w-full"
        placeholder="Purchase ID"
        value={form.purchaseId}
        onChange={e => setForm({ ...form, purchaseId: e.target.value })}
        required
      />
      <input
        className="border p-2 w-full"
        placeholder="Purchase Detail ID"
        value={form.purchaseDetailId}
        onChange={e => setForm({ ...form, purchaseDetailId: e.target.value })}
        required
      />
      <input
        type="number"
        className="border p-2 w-full"
        placeholder="Received Quantity"
        value={form.receivedQuantity}
        onChange={e =>
          setForm({ ...form, receivedQuantity: Number(e.target.value) })
        }
        required
      />
      <button type="submit" className="bg-blue-600 text-white px-4 py-2 rounded">
        Submit
      </button>
    </form>
  );
};

export default GoodsReceiptForm;
