import React, { useState, useEffect } from 'react';
import { useAppState, useAppActions, useAppDispatch } from '../../../context/MainContext';
import { Product,Customer } from '../../../types';
import { 
  Search, 
  Plus, 
  Minus, 
  Trash2, 
  ShoppingCart, 
  User, 
  CreditCard, 
  Banknote, 
  Smartphone,
  Package,
  X,
  AlertCircle,
  Calculator,
  Receipt,
  UserPlus,
  PauseCircle,
  PlayCircle
} from 'lucide-react';
import { holdSale, resumeSale } from '../../../services/sales';

const SalesInterface: React.FC = () => {
  const state = useAppState(s => s);
  const dispatch = useAppDispatch();
  const {
    createSale,
    searchProducts,
    searchCustomers,
    createCustomer,
    getProductsByCategory
  } = useAppActions();

  const [productSearchTerm, setProductSearchTerm] = useState('');
  const [customerSearchTerm, setCustomerSearchTerm] = useState('');
  const [showCustomerModal, setShowCustomerModal] = useState(false);
  const [showCheckoutModal, setShowCheckoutModal] = useState(false);
  const [showCustomerAddModal, setShowCustomerAddModal] = useState(false);
  const [filteredProducts, setFilteredProducts] = useState<Product[]>([]);
  const [filteredCustomers, setFilteredCustomers] = useState<Customer[]>([]);
  const [selectedPaymentMethod, setSelectedPaymentMethod] = useState<'cash' | 'card' | 'upi' | 'netbanking' | 'credit'>('cash');
  const [paymentReceived, setPaymentReceived] = useState(0);
  const [discount, setDiscount] = useState(0);
  const [notes, setNotes] = useState('');
  const [isProcessing, setIsProcessing] = useState(false);
  const [barcode, setBarcode] = useState('');
  const [loyaltyPointsUsed, setLoyaltyPointsUsed] = useState(0);
  const [promotionCode, setPromotionCode] = useState('');
  const [warranty, setWarranty] = useState('');
  const [currentSaleId, setCurrentSaleId] = useState('');
  
  const [newCustomerForm, setNewCustomerForm] = useState({
    name: '',
    phone: '',
    email: '',
    address: '',
    locationId: state.currentLocationId || '', // Use current location if available
    creditLimit: 0
  });

  useEffect(() => {
    // Filter products based on search and category
    let filtered = state.products.filter(p => p.stock > 0); // Only show products in stock
    
    if (productSearchTerm.trim()) {
      filtered = searchProducts(productSearchTerm).filter((p: Product) => p.stock > 0);
    } else if (state.selectedCategory !== 'All') {
      filtered = getProductsByCategory(state.selectedCategory).filter((p: Product) => p.stock > 0);
    }
    
    setFilteredProducts(filtered);
  }, [productSearchTerm, state.selectedCategory, state.products]);

  useEffect(() => {
  if (state.currentLocationId && !newCustomerForm.locationId) {
    setNewCustomerForm(prev => ({ ...prev, locationId: state.currentLocationId || '' }));
  }
}, [state.currentLocationId]);

  useEffect(() => {
    if (customerSearchTerm.trim()) {
      setFilteredCustomers(searchCustomers(customerSearchTerm));
    } else {
      setFilteredCustomers(state.customers.slice(0, 10)); // Show first 10 customers
    }
  }, [customerSearchTerm, state.customers]);

  useEffect(() => {
    // Auto-set payment received to total when payment method changes
    if (selectedPaymentMethod !== 'credit') {
      setPaymentReceived(getTotal());
    } else {
      setPaymentReceived(0);
    }
  }, [selectedPaymentMethod, state.cart, discount]);

  const addToCart = (product: Product) => {
    dispatch({ type: 'ADD_TO_CART', payload: product });
  };

  const removeFromCart = (productId: string) => {
    dispatch({ type: 'REMOVE_FROM_CART', payload: productId });
  };

  const updateQuantity = (productId: string, quantity: number) => {
    if (quantity <= 0) {
      removeFromCart(productId);
    } else {
      // Check if quantity exceeds stock
      const product = state.products.find(p => p._id === productId);
      if (product && quantity > product.stock) {
        alert(`Only ${product.stock} units available in stock`);
        return;
      }
      dispatch({ type: 'UPDATE_CART_QUANTITY', payload: { id: productId, quantity } });
    }
  };

  const selectCustomer = (customer: Customer) => {
    dispatch({ type: 'SET_CUSTOMER', payload: customer });
    setShowCustomerModal(false);
    setCustomerSearchTerm('');
  };

  const clearCustomer = () => {
    dispatch({ type: 'SET_CUSTOMER', payload: { name: '', phone: '', address: '', credit_balance: 0 } });
  };

  const getSubtotal = () => {
    return state.cart.reduce((sum, item) => sum + item.totalPrice, 0);
  };

  const getDiscountAmount = () => {
    const subtotal = getSubtotal();
    return (subtotal * discount) / 100;
  };

  const getTax = () => {
    const subtotal = getSubtotal();
    const discountAmount = getDiscountAmount();
    const taxableAmount = subtotal - discountAmount;
    return taxableAmount * 0.1; // 10% tax, adjust as needed
  };

  const getTotal = () => {
    const subtotal = getSubtotal();
    const discountAmount = getDiscountAmount();
    const tax = getTax();
    return subtotal - discountAmount + tax;
  };

  const getChange = () => {
    return Math.max(0, paymentReceived - getTotal());
  };

  const canProcessSale = () => {
    if (state.cart.length === 0) return false;
    if (selectedPaymentMethod === 'credit') {
      if (!state.customer._id) return false;
      const total = getTotal();
      const newBalance = (state.customer.credit_balance || 0) + total;
      return newBalance <= (state.customer.creditLimit || 0);
    }
    return paymentReceived >= getTotal();
  };

  const handleAddNewCustomer = async (e: React.FormEvent) => {
  e.preventDefault();
  try {
    const newCustomer = await createCustomer({
        ...newCustomerForm,
        locationId: newCustomerForm.locationId || state.currentLocationId, // Use form or current location
        credit_balance: 0,
        loyaltyPoints: 0,
        isActive: true
    });
    
    dispatch({ type: 'SET_CUSTOMER', payload: newCustomer });
    setShowCustomerAddModal(false);
    setShowCustomerModal(false);
    setNewCustomerForm({
      name: '',
      phone: '',
      email: '',
      address: '',
      locationId: '',
      creditLimit: 0
    });
  } catch (error: any) {
    console.error('Error adding customer:', error);
    alert('Error adding customer: ' + error.message);
  }
};

  const processSale = async () => {
    if (!canProcessSale()) return;

    setIsProcessing(true);
    try {
      const saleData = {
        customerId: state.customer._id,
        items: state.cart.map(item => ({
          productId: item.product._id,
          productName: item.product.name,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          totalPrice: item.totalPrice,
          discount: item.discount || 0
        })),
        subtotal: getSubtotal(),
        discount: getDiscountAmount(),
        tax: getTax(),
        total: getTotal(),
        paymentMethod: selectedPaymentMethod,
        paymentStatus: selectedPaymentMethod === 'credit' ? 'pending' as const : 'paid' as const,
        notes: notes.trim() || undefined,
        date: new Date().toISOString(),
        loyaltyPoints: loyaltyPointsUsed || undefined,
        promotionCode: promotionCode.trim() || undefined,
        warranty: warranty.trim() || undefined,
        barcode: barcode.trim() || undefined
      };

      await createSale(saleData);
      
      // Clear cart and reset form
      dispatch({ type: 'CLEAR_CART' });
      setDiscount(0);
      setNotes('');
      setPaymentReceived(0);
      setSelectedPaymentMethod('cash');
      setShowCheckoutModal(false);
      
      alert('Sale processed successfully!');
    } catch (error: any) {
      console.error('Error processing sale:', error);
      alert('Error processing sale: ' + error.message);
    } finally {
      setIsProcessing(false);
    }
  };

  const holdCurrentSale = async () => {
    setIsProcessing(true);
    try {
      const saleData = {
        customerId: state.customer._id,
        items: state.cart.map(item => ({
          productId: item.product._id,
          productName: item.product.name,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          totalPrice: item.totalPrice,
          discount: item.discount || 0
        })),
        subtotal: getSubtotal(),
        discount: getDiscountAmount(),
        tax: getTax(),
        total: getTotal(),
        paymentMethod: selectedPaymentMethod,
        paymentStatus: 'pending' as const,
        notes: notes.trim() || undefined,
        date: new Date().toISOString(),
        loyaltyPoints: loyaltyPointsUsed || undefined,
        promotionCode: promotionCode.trim() || undefined,
        warranty: warranty.trim() || undefined,
        barcode: barcode.trim() || undefined
      };

      const held = await createSale(saleData);
      setCurrentSaleId((held as any)._id);
      await holdSale((held as any)._id);
      dispatch({ type: 'CLEAR_CART' });
      alert('Sale held successfully!');
    } catch (error: any) {
      console.error('Error holding sale:', error);
      alert('Error holding sale: ' + error.message);
    } finally {
      setIsProcessing(false);
    }
  };

  const resumeHeldSale = async () => {
    if (!currentSaleId) return;
    setIsProcessing(true);
    try {
      await resumeSale(currentSaleId);
      alert('Sale resumed successfully!');
    } catch (error: any) {
      console.error('Error resuming sale:', error);
      alert('Error resuming sale: ' + error.message);
    } finally {
      setIsProcessing(false);
    }
  };

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD'
    }).format(amount);
  };

  // Handle categories that are stored as strings
  const categories = state.categories;

  return (
    <div className="flex h-full bg-gray-50 dark:bg-gray-950">
      {/* Left Panel - Categories and Products */}
      <div className="flex-1 flex flex-col">
        {/* Categories */}
        <div className="bg-white dark:bg-gray-900 border-b border-gray-200 dark:border-gray-700 p-4">
          <div className="flex flex-wrap gap-2">
            {categories.map((category) => (
              <button
                key={category}
                onClick={() => dispatch({ type: 'SET_CATEGORY', payload: category })}
                className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
                  state.selectedCategory === category
                    ? 'bg-red-600 text-white'
                    : 'bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-700'
                }`}
              >
                {category}
              </button>
            ))}
          </div>
        </div>

        {/* Product Search */}
        <div className="bg-white dark:bg-gray-900 border-b border-gray-200 dark:border-gray-700 p-4">
          <div className="space-y-2">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-5 h-5" />
              <input
                type="text"
                placeholder="Search products..."
                value={productSearchTerm}
                onChange={(e) => setProductSearchTerm(e.target.value)}
                className="w-full pl-10 pr-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white"
              />
            </div>
            <input
              type="text"
              placeholder="Scan barcode"
              value={barcode}
              onChange={(e) => setBarcode(e.target.value)}
              className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white"
            />
          </div>
        </div>

        {/* Products Grid */}
        <div className="flex-1 overflow-y-auto p-4">
          <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
            {filteredProducts.map((product) => (
              <div
                key={product._id}
                onClick={() => addToCart(product)}
                className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 p-4 cursor-pointer hover:shadow-lg hover:border-red-300 dark:hover:border-red-700 transition-all"
              >
                <div className="w-full h-24 bg-gray-100 dark:bg-gray-800 rounded-lg flex items-center justify-center mb-3">
                  <Package className="w-8 h-8 text-gray-400" />
                </div>
                
                <h3 className="text-sm font-medium text-gray-900 dark:text-white mb-1 line-clamp-2">
                  {product.name}
                </h3>
                
                <p className="text-xs text-gray-500 dark:text-gray-400 mb-2">
                  Stock: {product.stock}
                </p>
                
                <div className="flex items-center justify-between">
                  <span className="text-lg font-bold text-red-600 dark:text-red-400">
                    {formatCurrency(product.price)}
                  </span>
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      addToCart(product);
                    }}
                    className="w-8 h-8 bg-red-600 text-white rounded-lg flex items-center justify-center hover:bg-red-700 transition-colors"
                  >
                    <Plus className="w-4 h-4" />
                  </button>
                </div>
              </div>
            ))}
          </div>

          {filteredProducts.length === 0 && (
            <div className="text-center py-12">
              <Package className="w-12 h-12 text-gray-400 mx-auto mb-4" />
              <p className="text-gray-500 dark:text-gray-400">
                {productSearchTerm || state.selectedCategory !== 'All' 
                  ? 'No products found matching your search.' 
                  : 'No products available.'}
              </p>
            </div>
          )}
        </div>
      </div>

      {/* Right Panel - Cart */}
      <div className="w-96 bg-white dark:bg-gray-900 border-l border-gray-200 dark:border-gray-700 flex flex-col">
        {/* Cart Header */}
        <div className="p-4 border-b border-gray-200 dark:border-gray-700">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-lg font-semibold text-gray-800 dark:text-white flex items-center">
              <ShoppingCart className="w-5 h-5 mr-2" />
              Cart ({state.cart.length})
            </h2>
            {state.cart.length > 0 && (
              <button
                onClick={() => dispatch({ type: 'CLEAR_CART' })}
                className="text-red-600 hover:text-red-800 dark:text-red-400 dark:hover:text-red-300"
              >
                <Trash2 className="w-4 h-4" />
              </button>
            )}
          </div>

          {/* Customer Selection */}
          <div className="bg-gray-50 dark:bg-gray-800 rounded-lg p-3">
            {state.customer._id ? (
              <div className="flex items-center justify-between">
                <div className="flex items-center space-x-2">
                  <User className="w-4 h-4 text-gray-600 dark:text-gray-400" />
                  <div>
                    <div className="text-sm font-medium text-gray-800 dark:text-white">
                      {state.customer.name}
                    </div>
                    <div className="text-xs text-gray-500 dark:text-gray-400">
                      {state.customer.phone}
                    </div>
                    {(state.customer.credit_balance || 0) > 0 && (
                      <div className="text-xs text-red-600 dark:text-red-400">
                        Credit: {formatCurrency(state.customer.credit_balance || 0)}
                      </div>
                    )}
                  </div>
                </div>
                <button
                  onClick={clearCustomer}
                  className="text-gray-400 hover:text-gray-600 dark:hover:text-gray-300"
                >
                  <X className="w-4 h-4" />
                </button>
              </div>
            ) : (
              <button
                onClick={() => setShowCustomerModal(true)}
                className="w-full flex items-center justify-center space-x-2 text-gray-600 dark:text-gray-400 hover:text-gray-800 dark:hover:text-gray-200"
              >
                <User className="w-4 h-4" />
                <span className="text-sm">Select Customer (Optional)</span>
              </button>
            )}
          </div>
        </div>

        {/* Cart Items */}
        <div className="flex-1 overflow-y-auto p-4">
          {state.cart.length === 0 ? (
            <div className="text-center py-12">
              <ShoppingCart className="w-12 h-12 text-gray-400 mx-auto mb-4" />
              <p className="text-gray-500 dark:text-gray-400">Your cart is empty</p>
              <p className="text-sm text-gray-400 dark:text-gray-500">Add products to get started</p>
            </div>
          ) : (
            <div className="space-y-3">
              {state.cart.map((item) => (
                <div
                  key={item.product._id}
                  className="bg-gray-50 dark:bg-gray-800 rounded-lg p-3"
                >
                  <div className="flex items-center justify-between mb-2">
                    <h4 className="text-sm font-medium text-gray-800 dark:text-white line-clamp-2">
                      {item.product.name}
                    </h4>
                    <button
                      onClick={() => removeFromCart(item.product._id)}
                      className="text-red-600 hover:text-red-800 dark:text-red-400 dark:hover:text-red-300"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>
                  
                  <div className="flex items-center justify-between">
                    <div className="flex items-center space-x-2">
                      <button
                        onClick={() => updateQuantity(item.product._id, item.quantity - 1)}
                        className="w-6 h-6 bg-gray-200 dark:bg-gray-700 text-gray-600 dark:text-gray-400 rounded flex items-center justify-center hover:bg-gray-300 dark:hover:bg-gray-600"
                      >
                        <Minus className="w-3 h-3" />
                      </button>
                      <span className="text-sm font-medium text-gray-800 dark:text-white w-8 text-center">
                        {item.quantity}
                      </span>
                      <button
                        onClick={() => updateQuantity(item.product._id, item.quantity + 1)}
                        className="w-6 h-6 bg-gray-200 dark:bg-gray-700 text-gray-600 dark:text-gray-400 rounded flex items-center justify-center hover:bg-gray-300 dark:hover:bg-gray-600"
                      >
                        <Plus className="w-3 h-3" />
                      </button>
                    </div>
                    
                    <div className="text-right">
                      <div className="text-sm font-medium text-gray-800 dark:text-white">
                        {formatCurrency(item.totalPrice)}
                      </div>
                      <div className="text-xs text-gray-500 dark:text-gray-400">
                        {formatCurrency(item.unitPrice)} each
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
          <div className="border-t border-gray-200 dark:border-gray-700 p-4">
            <div className="space-y-2 mb-4">
              <div className="flex justify-between text-sm">
                <span className="text-gray-600 dark:text-gray-400">Subtotal:</span>
                <span className="text-gray-800 dark:text-white">{formatCurrency(getSubtotal())}</span>
              </div>
              {discount > 0 && (
                <div className="flex justify-between text-sm">
                  <span className="text-gray-600 dark:text-gray-400">Discount ({discount}%):</span>
                  <span className="text-red-600 dark:text-red-400">-{formatCurrency(getDiscountAmount())}</span>
                </div>
              )}
              <div className="flex justify-between text-sm">
                <span className="text-gray-600 dark:text-gray-400">Tax:</span>
                <span className="text-gray-800 dark:text-white">{formatCurrency(getTax())}</span>
              </div>
              <div className="flex justify-between text-lg font-semibold pt-2 border-t border-gray-200 dark:border-gray-700">
                <span className="text-gray-800 dark:text-white">Total:</span>
                <span className="text-gray-800 dark:text-white">{formatCurrency(getTotal())}</span>
              </div>
            </div>

            <button
              onClick={() => setShowCheckoutModal(true)}
              className="w-full bg-red-600 text-white py-3 rounded-lg font-medium hover:bg-red-700 transition-colors flex items-center justify-center space-x-2"
            >
              <Calculator className="w-4 h-4" />
              <span>Checkout</span>
            </button>
          </div>
        )}
      </div>

      {/* Customer Selection Modal */}
      {showCustomerModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white dark:bg-gray-900 rounded-xl p-6 w-full max-w-md mx-4 max-h-[80vh] overflow-hidden flex flex-col">
            <div className="flex justify-between items-center mb-4">
              <h3 className="text-lg font-semibold text-gray-800 dark:text-white">Select Customer</h3>
              <button
                onClick={() => {
                  setShowCustomerModal(false);
                  setCustomerSearchTerm('');
                }}
                className="p-1 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-full"
              >
                <X className="w-5 h-5 text-gray-500 dark:text-gray-400" />
              </button>
            </div>

            <div className="relative mb-4">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-5 h-5" />
              <input
                type="text"
                placeholder="Search customers..."
                value={customerSearchTerm}
                onChange={(e) => setCustomerSearchTerm(e.target.value)}
                className="w-full pl-10 pr-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white"
              />
            </div>

            <div className="flex-1 overflow-y-auto mb-4">
              <div className="space-y-2">
                {filteredCustomers.map((customer) => (
                  <button
                    key={customer._id}
                    onClick={() => selectCustomer(customer)}
                    className="w-full text-left p-3 border border-gray-200 dark:border-gray-700 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors"
                  >
                    <div className="flex items-center justify-between">
                      <div>
                        <div className="font-medium text-gray-800 dark:text-white">
                          {customer.name}
                        </div>
                        <div className="text-sm text-gray-500 dark:text-gray-400">
                          {customer.phone}
                        </div>
                        {customer.credit_balance > 0 && (
                          <div className="text-sm text-red-600 dark:text-red-400">
                            Credit: {formatCurrency(customer.credit_balance)}
                          </div>
                        )}
                      </div>
                      <User className="w-5 h-5 text-gray-400" />
                    </div>
                  </button>
                ))}
              </div>

              {filteredCustomers.length === 0 && (
                <div className="text-center py-8">
                  <User className="w-12 h-12 text-gray-400 mx-auto mb-4" />
                  <p className="text-gray-500 dark:text-gray-400">No customers found</p>
                </div>
              )}
            </div>

            <button
              onClick={() => setShowCustomerAddModal(true)}
              className="w-full flex items-center justify-center space-x-2 bg-red-600 text-white py-2 rounded-lg hover:bg-red-700 transition-colors"
            >
              <UserPlus className="w-4 h-4" />
              <span>Add New Customer</span>
            </button>
          </div>
        </div>
      )}

      {/* Add Customer Modal */}
      {showCustomerAddModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white dark:bg-gray-900 rounded-xl p-6 w-full max-w-md mx-4">
            <div className="flex justify-between items-center mb-4">
              <h3 className="text-lg font-semibold text-gray-800 dark:text-white">Add New Customer</h3>
              <button
                onClick={() => {
                  setShowCustomerAddModal(false);
                  setNewCustomerForm({
                    name: '',
                    phone: '',
                    email: '',
                    address: '',
                    locationId: state.currentLocationId || '', // Use current location if available
                    creditLimit: 0
                  });
                }}
                className="p-1 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-full"
              >
                <X className="w-5 h-5 text-gray-500 dark:text-gray-400" />
              </button>
            </div>

            <form onSubmit={handleAddNewCustomer} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Customer Name *
                </label>
                <input
                  type="text"
                  required
                  value={newCustomerForm.name}
                  onChange={(e) => setNewCustomerForm(prev => ({ ...prev, name: e.target.value }))}
                  className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Phone Number *
                </label>
                <input
                  type="tel"
                  required
                  value={newCustomerForm.phone}
                  onChange={(e) => setNewCustomerForm(prev => ({ ...prev, phone: e.target.value }))}
                  className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Email Address
                </label>
                <input
                  type="email"
                  value={newCustomerForm.email}
                  onChange={(e) => setNewCustomerForm(prev => ({ ...prev, email: e.target.value }))}
                  className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Credit Limit
                </label>
                <input
                  type="number"
                  min="0"
                  step="0.01"
                  value={newCustomerForm.creditLimit}
                  onChange={(e) => setNewCustomerForm(prev => ({ ...prev, creditLimit: parseFloat(e.target.value) || 0 }))}
                  className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white"
                />
              </div>

              <div className="flex space-x-3 pt-4">
                <button
                  type="button"
                  onClick={() => {
                    setShowCustomerAddModal(false);
                    setNewCustomerForm({
                      name: '',
                      phone: '',
                      email: '',
                      address: '',
                      locationId: state.currentLocationId || '', // Use current location if available
                      creditLimit: 0
                    });
                  }}
                  className="flex-1 px-4 py-2 border border-gray-300 dark:border-gray-600 text-gray-700 dark:text-gray-300 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-800"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="flex-1 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700"
                >
                  Add Customer
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Checkout Modal */}
      {showCheckoutModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white dark:bg-gray-900 rounded-xl p-6 w-full max-w-lg mx-4 max-h-[90vh] overflow-y-auto">
            <div className="flex justify-between items-center mb-6">
              <h3 className="text-lg font-semibold text-gray-800 dark:text-white">Checkout</h3>
              <button
                onClick={() => setShowCheckoutModal(false)}
                className="p-1 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-full"
              >
                <X className="w-5 h-5 text-gray-500 dark:text-gray-400" />
              </button>
            </div>

            {/* Order Summary */}
            <div className="bg-gray-50 dark:bg-gray-800 rounded-lg p-4 mb-6">
              <h4 className="font-medium text-gray-800 dark:text-white mb-3">Order Summary</h4>
              <div className="space-y-2 text-sm">
                <div className="flex justify-between">
                  <span className="text-gray-600 dark:text-gray-400">Subtotal:</span>
                  <span className="text-gray-800 dark:text-white">{formatCurrency(getSubtotal())}</span>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-gray-600 dark:text-gray-400">Discount:</span>
                  <div className="flex items-center space-x-2">
                    <input
                      type="number"
                      min="0"
                      max="100"
                      value={discount}
                      onChange={(e) => setDiscount(parseFloat(e.target.value) || 0)}
                      className="w-16 px-2 py-1 text-xs border border-gray-300 dark:border-gray-600 rounded focus:ring-1 focus:ring-red-500 dark:bg-gray-700 dark:text-white"
                    />
                    <span className="text-gray-600 dark:text-gray-400">%</span>
                    <span className="text-red-600 dark:text-red-400">-{formatCurrency(getDiscountAmount())}</span>
                  </div>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-gray-600 dark:text-gray-400">Loyalty Points:</span>
                  <input
                    type="number"
                    min="0"
                    value={loyaltyPointsUsed}
                    onChange={(e) => setLoyaltyPointsUsed(parseFloat(e.target.value) || 0)}
                    className="w-24 px-2 py-1 text-xs border border-gray-300 dark:border-gray-600 rounded focus:ring-1 focus:ring-red-500 dark:bg-gray-700 dark:text-white"
                  />
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-gray-600 dark:text-gray-400">Promotion Code:</span>
                  <input
                    type="text"
                    value={promotionCode}
                    onChange={(e) => setPromotionCode(e.target.value)}
                    className="w-32 px-2 py-1 text-xs border border-gray-300 dark:border-gray-600 rounded focus:ring-1 focus:ring-red-500 dark:bg-gray-700 dark:text-white"
                  />
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-gray-600 dark:text-gray-400">Warranty:</span>
                  <input
                    type="text"
                    value={warranty}
                    onChange={(e) => setWarranty(e.target.value)}
                    className="w-32 px-2 py-1 text-xs border border-gray-300 dark:border-gray-600 rounded focus:ring-1 focus:ring-red-500 dark:bg-gray-700 dark:text-white"
                  />
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-600 dark:text-gray-400">Tax (10%):</span>
                  <span className="text-gray-800 dark:text-white">{formatCurrency(getTax())}</span>
                </div>
                <div className="flex justify-between text-lg font-semibold pt-2 border-t border-gray-200 dark:border-gray-700">
                  <span className="text-gray-800 dark:text-white">Total:</span>
                  <span className="text-gray-800 dark:text-white">{formatCurrency(getTotal())}</span>
                </div>
              </div>
            </div>

            {/* Payment Method */}
            <div className="mb-6">
              <h4 className="font-medium text-gray-800 dark:text-white mb-3">Payment Method</h4>
              <div className="grid grid-cols-2 gap-2">
                {[
                  { key: 'cash', label: 'Cash', icon: Banknote },
                  { key: 'card', label: 'Card', icon: CreditCard },
                  { key: 'upi', label: 'UPI', icon: Smartphone },
                  { key: 'credit', label: 'Credit', icon: User }
                ].map(({ key, label, icon: Icon }) => (
                  <button
                    key={key}
                    onClick={() => setSelectedPaymentMethod(key as any)}
                    disabled={key === 'credit' && !state.customer._id}
                    className={`p-3 rounded-lg border text-center transition-colors disabled:opacity-50 disabled:cursor-not-allowed ${
                      selectedPaymentMethod === key
                        ? 'border-red-500 bg-red-50 dark:bg-red-900/30 text-red-700 dark:text-red-300'
                        : 'border-gray-300 dark:border-gray-600 text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-800'
                    }`}
                  >
                    <Icon className="w-5 h-5 mx-auto mb-1" />
                    <div className="text-sm font-medium">{label}</div>
                  </button>
                ))}
              </div>
            </div>

            {/* Payment Amount */}
            {selectedPaymentMethod !== 'credit' && (
              <div className="mb-6">
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                  Payment Received
                </label>
                <input
                  type="number"
                  min="0"
                  step="0.01"
                  value={paymentReceived}
                  onChange={(e) => setPaymentReceived(parseFloat(e.target.value) || 0)}
                  className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white"
                />
                {paymentReceived > getTotal() && (
                  <p className="text-sm text-green-600 dark:text-green-400 mt-1">
                    Change: {formatCurrency(getChange())}
                  </p>
                )}
              </div>
            )}

            {/* Credit Sale Info */}
            {selectedPaymentMethod === 'credit' && state.customer._id && (
              <div className="mb-6 p-4 bg-yellow-50 dark:bg-yellow-900/30 border border-yellow-200 dark:border-yellow-800 rounded-lg">
                <div className="flex items-center space-x-2 mb-2">
                  <AlertCircle className="w-5 h-5 text-yellow-600 dark:text-yellow-400" />
                  <span className="text-yellow-800 dark:text-yellow-300 font-medium">Credit Sale</span>
                </div>
                <div className="text-sm text-yellow-700 dark:text-yellow-400 space-y-1">
                  <div>Customer: {state.customer.name}</div>
                  <div>Current Balance: {formatCurrency(state.customer.credit_balance || 0)}</div>
                  <div>New Balance: {formatCurrency((state.customer.credit_balance || 0) + getTotal())}</div>
                  <div>Credit Limit: {formatCurrency(state.customer.creditLimit || 0)}</div>
                  {(state.customer.credit_balance || 0) + getTotal() > (state.customer.creditLimit || 0) && (
                    <div className="text-red-600 dark:text-red-400 font-medium">
                      ⚠️ Credit limit exceeded!
                    </div>
                  )}
                </div>
              </div>
            )}

            {/* Notes */}
            <div className="mb-6">
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                Notes (Optional)
              </label>
              <textarea
                value={notes}
                onChange={(e) => setNotes(e.target.value)}
                rows={2}
                className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white"
                placeholder="Add any notes for this sale..."
              />
            </div>
            {/* Hold/Resume Buttons */}
            <div className="flex space-x-2 mb-4">
              <button
                onClick={holdCurrentSale}
                disabled={isProcessing}
                className="flex-1 bg-yellow-500 text-white py-2 rounded-lg flex items-center justify-center space-x-1 hover:bg-yellow-600 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                <PauseCircle className="w-4 h-4" />
                <span>Hold Sale</span>
              </button>
              <button
                onClick={resumeHeldSale}
                disabled={!currentSaleId || isProcessing}
                className="flex-1 bg-green-600 text-white py-2 rounded-lg flex items-center justify-center space-x-1 hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                <PlayCircle className="w-4 h-4" />
                <span>Resume Sale</span>
              </button>
            </div>

            {/* Process Sale Button */}
            <button
              onClick={processSale}
              disabled={!canProcessSale() || isProcessing}
              className="w-full bg-red-600 text-white py-3 rounded-lg font-medium hover:bg-red-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors flex items-center justify-center space-x-2"
            >
              {isProcessing ? (
                <div className="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin"></div>
              ) : (
                <>
                  <Receipt className="w-4 h-4" />
                  <span>Process Sale</span>
                </>
              )}
            </button>

            {!canProcessSale() && !isProcessing && (
              <div className="mt-2 text-sm text-red-600 dark:text-red-400 text-center">
                {state.cart.length === 0 && 'Cart is empty'}
                {selectedPaymentMethod === 'credit' && !state.customer._id && 'Please select a customer for credit sale'}
                {selectedPaymentMethod === 'credit' && state.customer._id && 
                  (state.customer.credit_balance || 0) + getTotal() > (state.customer.creditLimit || 0) && 
                  'Credit limit exceeded'}
                {selectedPaymentMethod !== 'credit' && paymentReceived < getTotal() && 'Insufficient payment received'}
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
};

export default SalesInterface;