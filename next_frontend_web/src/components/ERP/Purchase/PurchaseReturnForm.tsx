import React, { useState } from 'react';
import { purchases } from '../../../services';

const PurchaseReturnForm: React.FC = () => {
  const [form, setForm] = useState({
    purchaseId: '',
    productId: '',
    quantity: 1,
    reason: '',
    unitPrice: 0,
  });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      await purchases.createPurchaseReturn({
        purchaseId: Number(form.purchaseId),
        reason: form.reason,
        items: [
          {
            productId: Number(form.productId),
            quantity: Number(form.quantity),
            unitPrice: Number(form.unitPrice),
          },
        ],
      });
      setForm({ purchaseId: '', productId: '', quantity: 1, reason: '', unitPrice: 0 });
    } catch (err) {
      console.error(err);
    }
  };

  return (
    <form onSubmit={handleSubmit} className="p-4 space-y-2">
      <h2 className="text-xl font-semibold">Purchase Return</h2>
      <input
        className="border p-2 w-full"
        placeholder="Purchase ID"
        value={form.purchaseId}
        onChange={e => setForm({ ...form, purchaseId: e.target.value })}
        required
      />
      <input
        className="border p-2 w-full"
        placeholder="Product ID"
        value={form.productId}
        onChange={e => setForm({ ...form, productId: e.target.value })}
        required
      />
      <input
        type="number"
        className="border p-2 w-full"
        placeholder="Quantity"
        value={form.quantity}
        onChange={e => setForm({ ...form, quantity: Number(e.target.value) })}
        required
      />
      <input
        type="number"
        className="border p-2 w-full"
        placeholder="Unit Price"
        value={form.unitPrice}
        onChange={e => setForm({ ...form, unitPrice: Number(e.target.value) })}
        required
      />
      <input
        className="border p-2 w-full"
        placeholder="Reason"
        value={form.reason}
        onChange={e => setForm({ ...form, reason: e.target.value })}
      />
      <button type="submit" className="bg-blue-600 text-white px-4 py-2 rounded">
        Submit
      </button>
    </form>
  );
};

export default PurchaseReturnForm;
