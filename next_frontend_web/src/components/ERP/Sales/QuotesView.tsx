import React, { useEffect, useState } from 'react';
import {
  getQuotes,
  createQuote,
  updateQuote,
  deleteQuote,
} from '../../../services/sales';
import { Quote } from '../../../types';

const QuotesView: React.FC = () => {
  const [quotes, setQuotes] = useState<Quote[]>([]);
  const [form, setForm] = useState<Partial<Quote>>({
    quoteNumber: '',
    total: 0,
  });
  const [editingId, setEditingId] = useState<string | null>(null);

  const load = async () => {
    try {
      const quotes = await getQuotes();
      setQuotes(quotes);
    } catch {
      setQuotes([]);
    }
  };

  useEffect(() => {
    load();
  }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (editingId) {
      await updateQuote(editingId, form);
    } else {
      await createQuote(form);
    }
    setForm({ quoteNumber: '', total: 0 });
    setEditingId(null);
    load();
  };

  const startEdit = (quote: Quote) => {
    setForm({ quoteNumber: quote.quoteNumber, total: quote.total });
    setEditingId(quote._id);
  };

  const handleDelete = async (id: string) => {
    await deleteQuote(id);
    load();
  };

    const printQuote = (_quote: Quote) => window.print();
  const shareQuote = (quote: Quote) => {
    const msg = `Quote ${quote.quoteNumber} Total: ${quote.total.toFixed(2)}`;
    window.open(`mailto:?subject=Quote&body=${encodeURIComponent(msg)}`);
  };

  return (
    <div className="p-4 space-y-4">
      <h2 className="text-xl font-semibold">Quotes</h2>
      <form onSubmit={handleSubmit} className="space-x-2">
        <input
          placeholder="Quote Number"
          value={form.quoteNumber || ''}
          onChange={e => setForm({ ...form, quoteNumber: e.target.value })}
          className="border px-2 py-1"
        />
        <input
          type="number"
          placeholder="Total"
          value={form.total ?? ''}
          onChange={e => setForm({ ...form, total: Number(e.target.value) })}
          className="border px-2 py-1"
        />
        <button
          type="submit"
          className="px-3 py-1 bg-blue-500 text-white rounded"
        >
          {editingId ? 'Update' : 'Create'}
        </button>
      </form>
      <table className="w-full border">
        <thead>
          <tr className="bg-gray-100">
            <th className="p-2 border">Quote #</th>
            <th className="p-2 border">Total</th>
            <th className="p-2 border">Actions</th>
          </tr>
        </thead>
        <tbody>
          {quotes.map(q => (
            <tr key={q._id} className="border-t">
              <td className="p-2 border">{q.quoteNumber}</td>
              <td className="p-2 border">{q.total}</td>
              <td className="p-2 border space-x-2">
                <button
                  onClick={() => startEdit(q)}
                  className="px-2 py-1 bg-yellow-500 text-white rounded"
                >
                  Edit
                </button>
                <button
                  onClick={() => handleDelete(q._id)}
                  className="px-2 py-1 bg-red-500 text-white rounded"
                >
                  Delete
                </button>
                <button
                  onClick={() => printQuote(q)}
                  className="px-2 py-1 bg-gray-200 rounded"
                >
                  Print
                </button>
                <button
                  onClick={() => shareQuote(q)}
                  className="px-2 py-1 bg-green-500 text-white rounded"
                >
                  Share
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
};

export default QuotesView;

