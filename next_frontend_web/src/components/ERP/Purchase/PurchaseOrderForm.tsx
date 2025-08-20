import React, { useState } from 'react';
import { purchases } from '../../../services';

const PurchaseOrderForm: React.FC = () => {
  const [form, setForm] = useState({
    supplierId: '',
    referenceNumber: '',
    productId: '',
    quantity: 1,
    unitPrice: 0,
  });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      await purchases.createPurchaseOrder({
        supplierId: form.supplierId,
        referenceNumber: form.referenceNumber,
        items: [
          {
            productId: Number(form.productId),
            quantity: Number(form.quantity),
            unitPrice: Number(form.unitPrice),
          },
        ],
      });
      setForm({ supplierId: '', referenceNumber: '', productId: '', quantity: 1, unitPrice: 0 });
    } catch (err) {
      console.error(err);
    }
  };

  return (
    <form onSubmit={handleSubmit} className="p-4 space-y-2">
      <h2 className="text-xl font-semibold">Purchase Order</h2>
      <input
        className="border p-2 w-full"
        placeholder="Supplier ID"
        value={form.supplierId}
        onChange={e => setForm({ ...form, supplierId: e.target.value })}
        required
      />
      <input
        className="border p-2 w-full"
        placeholder="Reference Number"
        value={form.referenceNumber}
        onChange={e => setForm({ ...form, referenceNumber: e.target.value })}
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
      <button type="submit" className="bg-blue-600 text-white px-4 py-2 rounded">
        Submit
      </button>
    </form>
  );
};

export default PurchaseOrderForm;
