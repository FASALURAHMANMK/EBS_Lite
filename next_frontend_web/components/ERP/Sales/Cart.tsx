import React, { useState, useEffect } from 'react';
import { useApp } from '../../../context/MainContext';
import { ShoppingCart, Plus, Minus, Trash2, X, CreditCard, Banknote, Search, User, Check } from 'lucide-react';

// Modal Component
const Modal: React.FC<{
  isOpen: boolean;
  onClose: () => void;
  title: string;
  children: React.ReactNode;
}> = ({ isOpen, onClose, title, children }) => {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white dark:bg-gray-900 rounded-lg p-6 w-full max-w-md mx-4">
        <div className="flex justify-between items-center mb-4">
          <h3 className="text-lg font-semibold text-gray-800 dark:text-white">{title}</h3>
          <button
            onClick={onClose}
            className="p-1 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-full transition-colors"
          >
            <X className="w-5 h-5 text-gray-500 dark:text-gray-400" />
          </button>
        </div>
        {children}
      </div>
    </div>
  );
};

// Customer Add Dialog
const CustomerAddDialog: React.FC<{
  isOpen: boolean;
  onClose: () => void;
  initialName: string;
  onSave: (customer: any) => void;
}> = ({ isOpen, onClose, initialName, onSave }) => {
  const [formData, setFormData] = useState({
    name: initialName,
    phone: '',
    address: '',
    creditBalance: 0
  });

  useEffect(() => {
    setFormData(prev => ({ ...prev, name: initialName }));
  }, [initialName]);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const newCustomer = {
      id: Date.now().toString(),
      ...formData,
      loyaltyPoints: 0
    };
    onSave(newCustomer);
    setFormData({ name: '', phone: '', address: '', creditBalance: 0 });
    onClose();
  };

  return (
    <Modal isOpen={isOpen} onClose={onClose} title="Add New Customer">
      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
            Customer Name *
          </label>
          <input
            type="text"
            value={formData.name}
            onChange={(e) => setFormData({ ...formData, name: e.target.value })}
            className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none focus:border-red-500 bg-white dark:bg-gray-800 text-gray-900 dark:text-white"
            required
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
            Phone Number *
          </label>
          <input
            type="tel"
            value={formData.phone}
            onChange={(e) => setFormData({ ...formData, phone: e.target.value })}
            className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none focus:border-red-500 bg-white dark:bg-gray-800 text-gray-900 dark:text-white"
            required
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
            Address
          </label>
          <input
            type="text"
            value={formData.address}
            onChange={(e) => setFormData({ ...formData, address: e.target.value })}
            className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none focus:border-red-500 bg-white dark:bg-gray-800 text-gray-900 dark:text-white"
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
            Credit Balance
          </label>
          <input
            type="number"
            value={formData.creditBalance}
            onChange={(e) => setFormData({ ...formData, creditBalance: Number(e.target.value) })}
            className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none focus:border-red-500 bg-white dark:bg-gray-800 text-gray-900 dark:text-white"
            min="0"
          />
        </div>
        <div className="flex space-x-3 pt-4">
          <button
            type="button"
            onClick={onClose}
            className="flex-1 px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors"
          >
            Cancel
          </button>
          <button
            type="submit"
            className="flex-1 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors"
          >
            Add Customer
          </button>
        </div>
      </form>
    </Modal>
  );
};

const Cart: React.FC = () => {
  const { state, dispatch } = useApp();
  const [customerSearch, setCustomerSearch] = useState('');
  const [showCustomerDropdown, setShowCustomerDropdown] = useState(false);
  const [filteredCustomers, setFilteredCustomers] = useState(state.customers);
  const [showCustomerDialog, setShowCustomerDialog] = useState(false);

  const subtotal = state.cart.reduce((sum, item) => sum + (item.product.price * item.quantity), 0);
  const tax = subtotal * 0.18; // 18% GST
  const discounts = 0; // You can implement discount calculation here
  const total = subtotal + tax - discounts;

  // Live search for customers
  useEffect(() => {
    if (customerSearch.trim() === '') {
      setFilteredCustomers(state.customers);
    } else {
      const filtered = state.customers.filter(customer =>
        customer.name.toLowerCase().includes(customerSearch.toLowerCase()) ||
        customer.phone.includes(customerSearch) ||
        customer.address?.toLowerCase().includes(customerSearch.toLowerCase())
      );
      setFilteredCustomers(filtered);
    }
  }, [customerSearch]);

  const updateQuantity = (productId: string, newQuantity: number) => {
    if (newQuantity <= 0) {
      dispatch({ type: 'REMOVE_FROM_CART', payload: productId });
    } else {
      dispatch({ type: 'UPDATE_CART_QUANTITY', payload: { id: productId, quantity: newQuantity } });
    }
  };

  const handleCustomerSelect = (customer: any) => {
    dispatch({ 
      type: 'SET_CUSTOMER', 
      payload: { 
        _id: customer._id,
        phone: customer.phone,
        name: customer.name,
        creditBalance: customer.creditBalance,
        address: customer.address
      } 
    });
    setCustomerSearch(customer.name);
    setShowCustomerDropdown(false);
  };

  const handleAddNewCustomer = () => {
    setShowCustomerDialog(true);
    setShowCustomerDropdown(false);
  };

  const handleSaveCustomer = (customer: any) => {
    dispatch({ type: 'ADD_CUSTOMER', payload: customer });
    handleCustomerSelect(customer);
  };

  const handleCheckout = () => {
    // Handle checkout logic
    alert('Proceeding to checkout...');
  };

  const clearCustomer = () => {
    dispatch({ type: 'SET_CUSTOMER', payload: { phone: '', name: '', creditBalance: 0, address: '' } });
    setCustomerSearch('');
  };

  return (
    <div className="w-96 bg-white dark:bg-gray-900 border-l border-gray-200 dark:border-gray-700 flex flex-col shadow-lg">
      {/* Cart Header */}
      <div className="p-4 border-b border-gray-200 dark:border-gray-700">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-lg font-semibold flex items-center space-x-2 text-gray-800 dark:text-white">
            <ShoppingCart className="w-5 h-5 text-red-600 dark:text-red-400" />
            <span>Shopping Cart</span>
          </h2>
        </div>

        {/* Customer Search and Selection */}
        <div className="space-y-3">
          <div className="relative">
            <Search className="absolute left-3 top-3 w-4 h-4 text-gray-400" />
            <input
              type="text"
              placeholder="Search customer by name, phone, or address..."
              value={customerSearch}
              onChange={(e) => {
                setCustomerSearch(e.target.value);
                setShowCustomerDropdown(e.target.value.length > 0);
              }}
              onFocus={() => customerSearch.length > 0 && setShowCustomerDropdown(true)}
              className="w-full pl-10 pr-4 py-3 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none focus:border-red-500 dark:focus:border-red-400 bg-white dark:bg-gray-800 text-gray-900 dark:text-white"
            />
            
            {/* Customer Dropdown */}
            {showCustomerDropdown && (
              <div className="absolute top-full left-0 right-0 mt-1 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-600 rounded-lg shadow-lg z-10 max-h-60 overflow-y-auto">
                {filteredCustomers.map((customer) => (
                  <div 
                    key={customer._id}
                    onClick={() => handleCustomerSelect(customer)}
                    className="p-3 hover:bg-gray-50 dark:hover:bg-gray-700 cursor-pointer border-b dark:border-gray-600 last:border-b-0"
                  >
                    <div className="flex items-center justify-between">
                      <div className="flex items-center space-x-3">
                        <User className="w-4 h-4 text-gray-400" />
                        <div>
                          <p className="font-medium text-gray-800 dark:text-white">{customer.name}</p>
                          <p className="text-sm text-gray-500 dark:text-gray-400">{customer.phone}</p>
                          {customer.address && (
                            <p className="text-xs text-gray-400 dark:text-gray-500">{customer.address}</p>
                          )}
                        </div>
                      </div>
                      <div className="text-right">
                        <div className={`text-sm font-medium ${
                          customer.creditBalance > 0 
                            ? 'text-green-600 dark:text-green-400' 
                            : 'text-gray-500 dark:text-gray-400'
                        }`}>
                          Credit: ₹{customer.creditBalance.toLocaleString()}
                        </div>
                        <div className="text-xs text-gray-400 dark:text-gray-500">
                          {customer.loyaltyPoints} points
                        </div>
                      </div>
                    </div>
                  </div>
                ))}
                
                {/* Add New Customer Option - Updated */}
                {customerSearch.trim() && filteredCustomers.length === 0 && (
                  <div 
                    onClick={handleAddNewCustomer}
                    className="p-3 hover:bg-gray-50 dark:hover:bg-gray-700 cursor-pointer border-t dark:border-gray-600 bg-gray-50 dark:bg-gray-800"
                  >
                    <div className="flex items-center space-x-2 text-red-600 dark:text-red-400">
                      <Plus className="w-4 h-4" />
                      <span className="text-sm font-medium">Add "{customerSearch}" as new customer</span>
                    </div>
                  </div>
                )}
              </div>
            )}
          </div>

          {/* Selected Customer Info */}
          {state.customer.name && (
            <div className="bg-gray-50 dark:bg-gray-800 rounded-lg p-3 border dark:border-gray-700">
              <div className="flex items-center justify-between">
                <div className="flex items-center space-x-2">
                  <User className="w-4 h-4 text-green-600 dark:text-green-400" />
                  <div>
                    <p className="font-medium text-gray-800 dark:text-white">{state.customer.name}</p>
                    <p className="text-sm text-gray-500 dark:text-gray-400">{state.customer.phone}</p>
                  </div>
                </div>
                <div className="text-right">
                  <div className={`text-sm font-medium ${
                    (state.customer.creditBalance || 0) > 0 
                      ? 'text-green-600 dark:text-green-400' 
                      : 'text-gray-500 dark:text-gray-400'
                  }`}>
                    Credit: ₹{(state.customer.creditBalance || 0).toLocaleString()}
                  </div>
                  <button 
                    onClick={clearCustomer}
                    className="text-xs text-red-500 hover:text-red-700 dark:text-red-400 dark:hover:text-red-300"
                  >
                    Clear
                  </button>
                </div>
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Cart Items */}
      <div className="flex-1 overflow-y-auto p-4">
        {state.cart.length === 0 ? (
          <div className="text-center py-8">
            <ShoppingCart className="w-16 h-16 text-gray-300 dark:text-gray-600 mx-auto mb-4" />
            <h3 className="text-lg font-medium text-gray-800 dark:text-white mb-2">Your cart is empty</h3>
            <p className="text-gray-500 dark:text-gray-400">Add some products to get started</p>
          </div>
        ) : (
          <div className="space-y-3">
            {state.cart.map((item) => (
              <div key={item.product._id} className="bg-gray-50 dark:bg-gray-800 rounded-lg p-3 border dark:border-gray-700">
                <div className="flex items-center justify-between mb-2">
                  <h4 className="font-medium text-gray-800 dark:text-white line-clamp-1">{item.product.name}</h4>
                  <button
                    onClick={() => dispatch({ type: 'REMOVE_FROM_CART', payload: item.product._id })}
                    className="p-1 hover:bg-gray-200 dark:hover:bg-gray-700 rounded transition-colors"
                  >
                    <Trash2 className="w-4 h-4 text-red-500" />
                  </button>
                </div>
                
                <div className="flex items-center justify-between">
                  <div className="flex items-center space-x-3">
                    <div className="flex items-center space-x-1 bg-white dark:bg-gray-700 rounded-lg border border-gray-200 dark:border-gray-600">
                      <button
                        onClick={() => updateQuantity(item.product._id, item.quantity - 1)}
                        className="p-1 hover:bg-gray-100 dark:hover:bg-gray-600 rounded-l-lg transition-colors"
                      >
                        <Minus className="w-4 h-4 text-gray-600 dark:text-gray-300" />
                      </button>
                      <span className="px-3 py-1 text-sm font-medium text-gray-800 dark:text-white min-w-[2rem] text-center">
                        {item.quantity}
                      </span>
                      <button
                        onClick={() => updateQuantity(item.product._id, item.quantity + 1)}
                        className="p-1 hover:bg-gray-100 dark:hover:bg-gray-600 rounded-r-lg transition-colors"
                      >
                        <Plus className="w-4 h-4 text-gray-600 dark:text-gray-300" />
                      </button>
                    </div>
                  </div>
                  
                  <div className="text-right">
                    <div className="text-sm text-gray-500 dark:text-gray-400">
                      ₹{item.product.price.toLocaleString()} each
                    </div>
                    <div className="font-semibold text-gray-800 dark:text-white">
                      ₹{(item.product.price * item.quantity).toLocaleString()}
                    </div>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Cart Summary */}
      {state.cart.length > 0 && (
        <div className="border-t border-gray-200 dark:border-gray-700 p-4 space-y-4">
          <div className="space-y-2">
            <div className="flex justify-between text-sm">
              <span className="text-gray-600 dark:text-gray-400">Subtotal:</span>
              <span className="text-gray-800 dark:text-white">₹{subtotal.toLocaleString()}</span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-gray-600 dark:text-gray-400">Tax (18%):</span>
              <span className="text-gray-800 dark:text-white">₹{tax.toLocaleString()}</span>
            </div>
            {discounts > 0 && (
              <div className="flex justify-between text-sm">
                <span className="text-gray-600 dark:text-gray-400">Discount:</span>
                <span className="text-green-600 dark:text-green-400">-₹{discounts.toLocaleString()}</span>
              </div>
            )}
            <div className="border-t border-gray-200 dark:border-gray-600 pt-2">
              <div className="flex justify-between font-semibold text-lg">
                <span className="text-gray-800 dark:text-white">Total:</span>
                <span className="text-red-600 dark:text-red-400">₹{total.toLocaleString()}</span>
              </div>
            </div>
          </div>

          <div className="space-y-2">
            <button className="w-full bg-red-600 dark:bg-red-500 text-white py-3 rounded-lg hover:bg-red-700 dark:hover:bg-red-400 transition-colors flex items-center justify-center space-x-2">
              <CreditCard className="w-5 h-5" />
              <span>Checkout</span>
            </button>
            <button className="w-full bg-gray-600 dark:bg-gray-500 text-white py-2 rounded-lg hover:bg-gray-700 dark:hover:bg-gray-400 transition-colors flex items-center justify-center space-x-2">
              <Banknote className="w-4 h-4" />
              <span>Cash Payment</span>
            </button>
          </div>
        </div>
      )}

      {/* Customer Add Dialog */}
      <CustomerAddDialog
        isOpen={showCustomerDialog}
        onClose={() => setShowCustomerDialog(false)}
        initialName={customerSearch}
        onSave={handleSaveCustomer}
      />
    </div>
  );
};

export default Cart;