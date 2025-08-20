import React, { useEffect, useState } from 'react';
import { useAppState, useAppActions } from '../../../context/MainContext';
import { Supplier } from '../../../types';
import { Plus, Edit3, Trash2 } from 'lucide-react';

const SupplierManagement: React.FC = () => {
  const suppliers = useAppState(s => s.suppliers);
  const { loadSuppliers, createSupplier, updateSupplier, deleteSupplier } = useAppActions();

  const [formData, setFormData] = useState({ name: '', contact: '', email: '', address: '' });
  const [editingId, setEditingId] = useState<string | null>(null);

  useEffect(() => {
    loadSuppliers();
  }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      if (editingId) {
        await updateSupplier(editingId, formData);
      } else {
        await createSupplier({ ...formData, isActive: true });
      }
      setFormData({ name: '', contact: '', email: '', address: '' });
      setEditingId(null);
    } catch (err) {
      console.error(err);
    }
  };

  const handleEdit = (s: Supplier) => {
    setFormData({ name: s.name, contact: s.contact, email: s.email || '', address: s.address || '' });
    setEditingId(s._id);
  };

  const handleDelete = async (id: string) => {
    if (window.confirm('Delete this supplier?')) {
      await deleteSupplier(id);
    }
  };

  return (
    <div className="p-4">
      <h2 className="text-xl font-semibold mb-4">Suppliers</h2>
      <form onSubmit={handleSubmit} className="mb-6 space-y-2">
        <input
          className="border p-2 w-full"
          placeholder="Name"
          value={formData.name}
          onChange={e => setFormData({ ...formData, name: e.target.value })}
          required
        />
        <input
          className="border p-2 w-full"
          placeholder="Contact"
          value={formData.contact}
          onChange={e => setFormData({ ...formData, contact: e.target.value })}
          required
        />
        <input
          className="border p-2 w-full"
          placeholder="Email"
          value={formData.email}
          onChange={e => setFormData({ ...formData, email: e.target.value })}
        />
        <input
          className="border p-2 w-full"
          placeholder="Address"
          value={formData.address}
          onChange={e => setFormData({ ...formData, address: e.target.value })}
        />
        <button type="submit" className="bg-blue-600 text-white px-4 py-2 rounded flex items-center">
          {editingId ? <Edit3 className="w-4 h-4 mr-1" /> : <Plus className="w-4 h-4 mr-1" />}
          {editingId ? 'Update Supplier' : 'Add Supplier'}
        </button>
      </form>

      <table className="w-full border">
        <thead>
          <tr>
            <th className="border p-2 text-left">Name</th>
            <th className="border p-2 text-left">Contact</th>
            <th className="border p-2 text-left">Email</th>
            <th className="border p-2">Actions</th>
          </tr>
        </thead>
        <tbody>
          {suppliers.map(s => (
            <tr key={s._id} className="border-t">
              <td className="p-2">{s.name}</td>
              <td className="p-2">{s.contact}</td>
              <td className="p-2">{s.email || '-'}</td>
              <td className="p-2 space-x-2 text-center">
                <button onClick={() => handleEdit(s)} className="text-blue-600"><Edit3 className="w-4 h-4" /></button>
                <button onClick={() => handleDelete(s._id)} className="text-red-600"><Trash2 className="w-4 h-4" /></button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
};

export default SupplierManagement;
