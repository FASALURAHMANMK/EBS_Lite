import React, { useState } from 'react';
import { accounting } from '../../../services';

const VoucherEntry: React.FC = () => {
  const [type, setType] = useState('payment');
  const [amount, setAmount] = useState(0);
  const [description, setDescription] = useState('');
  const [message, setMessage] = useState('');

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      await accounting.createVoucher(type, { amount, description });
      setMessage('Voucher created');
      setAmount(0);
      setDescription('');
    } catch (err: any) {
      setMessage(err.message);
    }
  };

  return (
    <form onSubmit={submit} className="p-4 space-y-4">
      <h1 className="text-2xl font-bold">Voucher Entry</h1>
      {message && <p>{message}</p>}
      <div>
        <label className="block mb-1">Type</label>
        <select value={type} onChange={(e) => setType(e.target.value)} className="border p-2">
          <option value="payment">Payment</option>
          <option value="receipt">Receipt</option>
          <option value="journal">Journal</option>
        </select>
      </div>
      <div>
        <label className="block mb-1">Amount</label>
        <input
          type="number"
          value={amount}
          onChange={(e) => setAmount(parseFloat(e.target.value))}
          className="border p-2 w-full"
        />
      </div>
      <div>
        <label className="block mb-1">Description</label>
        <textarea
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          className="border p-2 w-full"
        />
      </div>
      <button type="submit" className="bg-red-600 text-white px-4 py-2 rounded">
        Save Voucher
      </button>
    </form>
  );
};

export default VoucherEntry;
