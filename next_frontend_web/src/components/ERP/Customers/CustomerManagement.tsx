import React, { useState, useEffect } from 'react';
import { useAppState, useAppActions } from '../../../context/MainContext';
import { useAuth } from '../../../context/AuthContext';
import { Customer, CreditTransaction, Location } from '../../../types';
import { Search, Plus, Upload, Download, X, Save } from 'lucide-react';
import CustomerList from './CustomerList';
import CustomerSummaryModal from './CustomerSummaryModal';
import CollectionEntryModal from './CollectionEntryModal';
import CreditHistoryModal from './CreditHistoryModal';
import * as XLSX from 'xlsx';

const CustomerManagement: React.FC = () => {
  const state = useAppState(s => s);
  const { state: authState } = useAuth();
  const {
    loadCustomers,
    createCustomer,
    updateCustomer,
    deleteCustomer,
    updateCustomerCredit,
    getCustomerCreditHistory,
    searchCustomers
  } = useAppActions();

  const [searchTerm, setSearchTerm] = useState('');
  const [filteredCustomers, setFilteredCustomers] = useState<Customer[]>([]);

  const [showAddModal, setShowAddModal] = useState(false);
  const [showEditModal, setShowEditModal] = useState(false);
  const [selectedCustomer, setSelectedCustomer] = useState<Customer | null>(null);

  const [summaryCustomer, setSummaryCustomer] = useState<Customer | null>(null);
  const [creditCustomer, setCreditCustomer] = useState<Customer | null>(null);
  const [historyCustomer, setHistoryCustomer] = useState<Customer | null>(null);
  const [creditHistory, setCreditHistory] = useState<CreditTransaction[]>([]);

  const [formData, setFormData] = useState({
    name: '',
    phone: '',
    email: '',
    address: '',
    locationId: '',
    creditLimit: 0,
    notes: ''
  });

  useEffect(() => {
    loadCustomers();
  }, []);

  useEffect(() => {
    const filtered = searchTerm.trim()
      ? searchCustomers(searchTerm)
      : state.customers;
    setFilteredCustomers(filtered);
  }, [searchTerm, state.customers]);

  const resetForm = () =>
    setFormData({
      name: '',
      phone: '',
      email: '',
      address: '',
      locationId: state.currentLocationId || '',
      creditLimit: 0,
      notes: ''
    });

  const handleAddCustomer = async (e: React.FormEvent) => {
    e.preventDefault();
    await createCustomer({
      ...formData,
      creditBalance: 0,
      loyaltyPoints: 0,
      isActive: true
    });
    setShowAddModal(false);
    resetForm();
  };

  const openEdit = (customer: Customer) => {
    setSelectedCustomer(customer);
    setFormData({
      name: customer.name,
      phone: customer.phone,
      email: customer.email || '',
      address: customer.address || '',
      locationId: customer.locationId,
      creditLimit: customer.creditLimit,
      notes: customer.notes || ''
    });
    setShowEditModal(true);
  };

  const handleEditCustomer = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedCustomer) return;
    await updateCustomer(selectedCustomer._id, formData);
    setShowEditModal(false);
    setSelectedCustomer(null);
    resetForm();
  };

  const handleDeleteCustomer = async (id: string) => {
    if (window.confirm('Are you sure you want to delete this customer?')) {
      await deleteCustomer(id);
    }
  };

  const handleCreditTransaction = async (
    amount: number,
    type: 'credit' | 'debit',
    description: string
  ) => {
    if (!creditCustomer) return;
    await updateCustomerCredit(creditCustomer._id, amount, type, description);
    setCreditCustomer(null);
  };

  const handleViewHistory = async (customer: Customer) => {
    const history = await getCustomerCreditHistory(customer._id);
    setHistoryCustomer(customer);
    setCreditHistory(history);
  };

  const handleExport = () => {
    const ws = XLSX.utils.json_to_sheet(state.customers);
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'Customers');
    XLSX.writeFile(wb, 'customers.xlsx');
  };

  const handleImport = async (
    e: React.ChangeEvent<HTMLInputElement>
  ) => {
    const file = e.target.files?.[0];
    if (!file) return;
    const data = await file.arrayBuffer();
    const workbook = XLSX.read(data);
    const sheet = workbook.Sheets[workbook.SheetNames[0]];
    const json: any[] = XLSX.utils.sheet_to_json(sheet);
    for (const row of json) {
      if (row.name && row.phone) {
        await createCustomer({
          name: row.name,
          phone: row.phone.toString(),
          email: row.email || '',
          address: row.address || '',
          locationId: state.currentLocationId || '',
          creditLimit: Number(row.creditLimit) || 0,
          notes: row.notes || '',
          creditBalance: 0,
          loyaltyPoints: 0,
          isActive: true
        });
      }
    }
    e.target.value = '';
  };

  return (
    <div className="flex-1 p-6 bg-gray-50 dark:bg-gray-950">
      <div className="mb-6 flex items-center justify-between">
        <h1 className="text-3xl font-bold text-gray-800 dark:text-white">
          Customer Management
        </h1>
      </div>

      <div className="bg-white dark:bg-gray-900 rounded-xl p-4 mb-6 border border-gray-200 dark:border-gray-700">
        <div className="flex flex-col sm:flex-row gap-4 items-center justify-between">
          <div className="relative flex-1 max-w-md">
            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-5 h-5" />
            <input
              type="text"
              placeholder="Search customers..."
              value={searchTerm}
              onChange={e => setSearchTerm(e.target.value)}
              className="w-full pl-10 pr-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white"
            />
          </div>
          <div className="flex gap-2">
            <button
              onClick={handleExport}
              className="flex items-center space-x-2 px-3 py-2 border rounded-lg text-gray-700 dark:text-gray-300"
            >
              <Download className="w-4 h-4" />
              <span>Export</span>
            </button>
            <label className="flex items-center space-x-2 px-3 py-2 border rounded-lg cursor-pointer text-gray-700 dark:text-gray-300">
              <Upload className="w-4 h-4" />
              <span>Import</span>
              <input type="file" accept=".xlsx,.xls" onChange={handleImport} className="hidden" />
            </label>
            <button
              onClick={() => setShowAddModal(true)}
              className="flex items-center space-x-2 bg-red-600 text-white px-4 py-2 rounded-lg hover:bg-red-700"
            >
              <Plus className="w-4 h-4" />
              <span>Add Customer</span>
            </button>
          </div>
        </div>
      </div>

      <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 overflow-hidden">
        <CustomerList
          customers={filteredCustomers}
          onEdit={openEdit}
          onCredit={c => setCreditCustomer(c)}
          onHistory={handleViewHistory}
          onSummary={c => setSummaryCustomer(c)}
          onDelete={handleDeleteCustomer}
        />
      </div>

      <CustomerSummaryModal
        customer={summaryCustomer}
        onClose={() => setSummaryCustomer(null)}
      />

      <CollectionEntryModal
        customer={creditCustomer}
        onSubmit={handleCreditTransaction}
        onClose={() => setCreditCustomer(null)}
      />

      <CreditHistoryModal
        customer={historyCustomer}
        history={creditHistory}
        onClose={() => setHistoryCustomer(null)}
      />

      {/* Add Customer Modal */}
      {showAddModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white dark:bg-gray-900 rounded-xl p-6 w-full max-w-md mx-4">
            <div className="flex justify-between items-center mb-4">
              <h3 className="text-lg font-semibold text-gray-800 dark:text-white">Add New Customer</h3>
              <button onClick={() => { setShowAddModal(false); resetForm(); }} className="p-1 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-full">
                <X className="w-5 h-5 text-gray-500 dark:text-gray-400" />
              </button>
            </div>
            <form onSubmit={handleAddCustomer} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Customer Name *</label>
                <input type="text" required value={formData.name} onChange={e => setFormData(prev => ({ ...prev, name: e.target.value }))} className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Phone Number *</label>
                <input type="tel" required value={formData.phone} onChange={e => setFormData(prev => ({ ...prev, phone: e.target.value }))} className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Email Address</label>
                <input type="email" value={formData.email} onChange={e => setFormData(prev => ({ ...prev, email: e.target.value }))} className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Address</label>
                <textarea value={formData.address} onChange={e => setFormData(prev => ({ ...prev, address: e.target.value }))} rows={2} className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Location *</label>
                <select required value={formData.locationId} onChange={e => setFormData(prev => ({ ...prev, locationId: e.target.value }))} className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white">
                  <option value="">Select Location</option>
                  {authState.company?.locations?.map((loc: Location) => (
                    <option key={loc._id} value={loc._id}>{loc.name}</option>
                  ))}
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Credit Limit</label>
                <input type="number" value={formData.creditLimit} onChange={e => setFormData(prev => ({ ...prev, creditLimit: parseFloat(e.target.value) || 0 }))} className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Notes</label>
                <textarea value={formData.notes} onChange={e => setFormData(prev => ({ ...prev, notes: e.target.value }))} rows={2} className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white" />
              </div>
              <div className="flex space-x-3 pt-4">
                <button type="button" onClick={() => { setShowAddModal(false); resetForm(); }} className="flex-1 px-4 py-2 border border-gray-300 dark:border-gray-600 text-gray-700 dark:text-gray-300 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-800">Cancel</button>
                <button type="submit" className="flex-1 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 flex items-center justify-center space-x-2"><Save className="w-4 h-4" /><span>Save</span></button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Edit Customer Modal */}
      {showEditModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white dark:bg-gray-900 rounded-xl p-6 w-full max-w-md mx-4">
            <div className="flex justify-between items-center mb-4">
              <h3 className="text-lg font-semibold text-gray-800 dark:text-white">Edit Customer</h3>
              <button onClick={() => { setShowEditModal(false); setSelectedCustomer(null); resetForm(); }} className="p-1 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-full">
                <X className="w-5 h-5 text-gray-500 dark:text-gray-400" />
              </button>
            </div>
            <form onSubmit={handleEditCustomer} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Customer Name *</label>
                <input type="text" required value={formData.name} onChange={e => setFormData(prev => ({ ...prev, name: e.target.value }))} className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Phone Number *</label>
                <input type="tel" required value={formData.phone} onChange={e => setFormData(prev => ({ ...prev, phone: e.target.value }))} className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Email Address</label>
                <input type="email" value={formData.email} onChange={e => setFormData(prev => ({ ...prev, email: e.target.value }))} className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Address</label>
                <textarea value={formData.address} onChange={e => setFormData(prev => ({ ...prev, address: e.target.value }))} rows={2} className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Location *</label>
                <select required value={formData.locationId} onChange={e => setFormData(prev => ({ ...prev, locationId: e.target.value }))} className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white">
                  <option value="">Select Location</option>
                  {authState.company?.locations?.map((loc: Location) => (
                    <option key={loc._id} value={loc._id}>{loc.name}</option>
                  ))}
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Credit Limit</label>
                <input type="number" value={formData.creditLimit} onChange={e => setFormData(prev => ({ ...prev, creditLimit: parseFloat(e.target.value) || 0 }))} className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Notes</label>
                <textarea value={formData.notes} onChange={e => setFormData(prev => ({ ...prev, notes: e.target.value }))} rows={2} className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white" />
              </div>
              <div className="flex space-x-3 pt-4">
                <button type="button" onClick={() => { setShowEditModal(false); setSelectedCustomer(null); resetForm(); }} className="flex-1 px-4 py-2 border border-gray-300 dark:border-gray-600 text-gray-700 dark:text-gray-300 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-800">Cancel</button>
                <button type="submit" className="flex-1 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 flex items-center justify-center space-x-2"><Save className="w-4 h-4" /><span>Update</span></button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

export default CustomerManagement;
