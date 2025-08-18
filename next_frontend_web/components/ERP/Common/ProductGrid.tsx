import React, { useState, useEffect } from 'react';
import { useApp } from '../../../context/MainContext';
import { useAuth } from '../../../context/AuthContext';
import { Search, ScanLine, Package, AlertTriangle, Plus, X } from 'lucide-react';

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

// Product Add Dialog
const ProductAddDialog: React.FC<{
  isOpen: boolean;
  onClose: () => void;
  initialName: string;
  onSave: (product: any) => void;
}> = ({ isOpen, onClose, initialName, onSave }) => {
  const { state } = useApp();
  const { state: authState } = useAuth();
 const [formData, setFormData] = useState({
  name: initialName,
  price: 0,
  stock: 0,
  category: state.selectedCategory === 'All' ? state.categories[1] : state.selectedCategory,
  locationId: state.currentLocationId || '', // Add this
  brand: '',
  model: '',
  sku: '',
  warranty: '',
  description: ''
});

  useEffect(() => {
    setFormData(prev => ({ ...prev, name: initialName }));
  }, [initialName]);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const newProduct = {
      id: Date.now().toString(),
      ...formData,
    };
    onSave(newProduct);
    setFormData({
      name: '',
      price: 0,
      stock: 0,
      category: state.selectedCategory === 'All' ? state.categories[1] : state.selectedCategory,
      locationId: state.currentLocationId || '',
      brand: '',
      model: '',
      sku: '',
      warranty: '',
      description: ''
    });
    onClose();
  };

  return (
    <Modal isOpen={isOpen} onClose={onClose} title="Add New Product">
      <form onSubmit={handleSubmit} className="space-y-4 max-h-96 overflow-y-auto">
        <div>
          <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
            Product Name *
          </label>
          <input
            type="text"
            value={formData.name}
            onChange={(e) => setFormData({ ...formData, name: e.target.value })}
            className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none focus:border-red-500 bg-white dark:bg-gray-800 text-gray-900 dark:text-white"
            required
          />
        </div>
        
        <div className="grid grid-cols-2 gap-3">
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
              Price *
            </label>
            <input
              type="number"
              value={formData.price}
              onChange={(e) => setFormData({ ...formData, price: Number(e.target.value) })}
              className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none focus:border-red-500 bg-white dark:bg-gray-800 text-gray-900 dark:text-white"
              min="0"
              step="0.01"
              required
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
              Stock *
            </label>
            <input
              type="number"
              value={formData.stock}
              onChange={(e) => setFormData({ ...formData, stock: Number(e.target.value) })}
              className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none focus:border-red-500 bg-white dark:bg-gray-800 text-gray-900 dark:text-white"
              min="0"
              required
            />
          </div>
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
            Category *
          </label>
          <select
            value={formData.category}
            onChange={(e) => setFormData({ ...formData, category: e.target.value })}
            className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none focus:border-red-500 bg-white dark:bg-gray-800 text-gray-900 dark:text-white"
            required
          >
            {state.categories.filter(cat => cat !== 'All').map(category => (
              <option key={category} value={category}>{category}</option>
            ))}
          </select>
        </div>

        <div>
  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
    Location *
  </label>
  <select
    value={formData.locationId}
    onChange={(e) => setFormData({ ...formData, locationId: e.target.value })}
    className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none focus:border-red-500 bg-white dark:bg-gray-800 text-gray-900 dark:text-white"
    required
  >
    <option value="">Select Location</option>
    {authState.company?.locations?.filter(loc => loc.isActive).map(location => (
      <option key={location._id} value={location._id}>
        {location.name}
      </option>
    ))}
  </select>
</div>

        <div className="grid grid-cols-2 gap-3">
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
              Brand
            </label>
            <input
              type="text"
              value={formData.brand}
              onChange={(e) => setFormData({ ...formData, brand: e.target.value })}
              className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none focus:border-red-500 bg-white dark:bg-gray-800 text-gray-900 dark:text-white"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
              Model
            </label>
            <input
              type="text"
              value={formData.model}
              onChange={(e) => setFormData({ ...formData, model: e.target.value })}
              className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none focus:border-red-500 bg-white dark:bg-gray-800 text-gray-900 dark:text-white"
            />
          </div>
        </div>

        <div className="grid grid-cols-2 gap-3">
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
              SKU
            </label>
            <input
              type="text"
              value={formData.sku}
              onChange={(e) => setFormData({ ...formData, sku: e.target.value })}
              className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none focus:border-red-500 bg-white dark:bg-gray-800 text-gray-900 dark:text-white"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
              Warranty
            </label>
            <input
              type="text"
              value={formData.warranty}
              onChange={(e) => setFormData({ ...formData, warranty: e.target.value })}
              className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none focus:border-red-500 bg-white dark:bg-gray-800 text-gray-900 dark:text-white"
            />
          </div>
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
            Description
          </label>
          <textarea
            value={formData.description}
            onChange={(e) => setFormData({ ...formData, description: e.target.value })}
            className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none focus:border-red-500 bg-white dark:bg-gray-800 text-gray-900 dark:text-white"
            rows={3}
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
            Add Product
          </button>
        </div>
      </form>
    </Modal>
  );
};

const ProductGrid: React.FC = () => {
  const { state, dispatch } = useApp();
  const [searchTerm, setSearchTerm] = useState('');
  const [showProductDialog, setShowProductDialog] = useState(false);
  const [showProductDropdown, setShowProductDropdown] = useState(false);

  const filteredProducts = state.products.filter(product => {
    const matchesCategory = state.selectedCategory === 'All' || product.category === state.selectedCategory;
    const matchesSearch = searchTerm === '' || 
      product.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      product.sku?.toLowerCase().includes(searchTerm.toLowerCase()) ||
      product.brand?.toLowerCase().includes(searchTerm.toLowerCase());
    
    return matchesCategory && matchesSearch;
  });

  const getCartQuantity = (productId: string) => {
    const cartItem = state.cart.find(item => item.product._id === productId);
    return cartItem ? cartItem.quantity : 0;
  };

  const getStockStatus = (stock: number) => {
    if (stock === 0) return { label: 'Out of Stock', color: 'text-red-600 dark:text-red-400', bgColor: 'bg-red-50 dark:bg-red-900/30' };
    if (stock <= 5) return { label: 'Low Stock', color: 'text-yellow-600 dark:text-yellow-400', bgColor: 'bg-yellow-50 dark:bg-yellow-900/30' };
    return { label: 'In Stock', color: 'text-green-600 dark:text-green-400', bgColor: 'bg-green-50 dark:bg-green-900/30' };
  };

  const handleProductClick = (product: any) => {
    if (product.stock > 0) {
      dispatch({ type: 'ADD_TO_CART', payload: product });
    }
  };

  const handleScanBarcode = () => {
    // Implement barcode scanning logic
    alert('Barcode scanning feature - integrate with camera API');
  };

  const handleAddNewProduct = () => {
    setShowProductDialog(true);
    setShowProductDropdown(false);
  };

  const handleSaveProduct = (product: any) => {
    dispatch({ type: 'ADD_PRODUCT', payload: product });
  };

  const hasNoResults = searchTerm.trim() && filteredProducts.length === 0;

  return (
    <div className="flex-1 p-6 bg-gray-50 dark:bg-gray-950">
      {/* Header */}
      <div className="mb-6">
        <div className="flex items-center justify-between mb-4">
          <div>
            <h1 className="text-2xl font-bold text-gray-800 dark:text-white">Products</h1>
            <p className="text-gray-600 dark:text-gray-400">
              Search / Scan Products
            </p>
          </div>
        </div>

        {/* Enhanced Search Bar with Integrated Actions */}
        <div className="relative">
          <div className="relative">
            <Search className="absolute left-3 top-3 w-5 h-5 text-gray-400" />
            <input
              type="text"
              placeholder="Search by product name, SKU, or brand..."
              value={searchTerm}
              onChange={(e) => {
                setSearchTerm(e.target.value);
                setShowProductDropdown(e.target.value.length > 0);
              }}
              onFocus={() => searchTerm.length > 0 && setShowProductDropdown(true)}
              className="w-full pl-10 pr-24 py-3 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none focus:border-red-500 dark:focus:border-red-400 bg-white dark:bg-gray-800 text-gray-900 dark:text-white"
            />
            
            {/* Integrated Action Buttons */}
            <div className="absolute right-2 top-2 flex items-center space-x-1">
              <button
                onClick={handleScanBarcode}
                className="p-1.5 text-gray-500 hover:text-red-600 dark:text-gray-400 dark:hover:text-red-400 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-md transition-colors"
                title="Scan Barcode"
              >
                <ScanLine className="w-4 h-4" />
              </button>
            </div>
          </div>

          {/* Search Dropdown */}
          {showProductDropdown && (
            <div className="absolute top-full left-0 right-0 mt-1 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-600 rounded-lg shadow-lg z-10 max-h-60 overflow-y-auto">
              
              {/* Show "Add new product" option when no results found */}
              {hasNoResults && (
                <div 
                  onClick={handleAddNewProduct}
                  className="p-3 hover:bg-gray-50 dark:hover:bg-gray-700 cursor-pointer border-t dark:border-gray-600 bg-gray-50 dark:bg-gray-800"
                >
                  <div className="flex items-center space-x-2 text-red-600 dark:text-red-400">
                    <Plus className="w-4 h-4" />
                    <span className="text-sm font-medium">Add "{searchTerm}" as new product</span>
                  </div>
                </div>
              )}
            </div>
          )}
        </div>
      </div>

      {/* Products Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
        {filteredProducts.map((product) => {
          const quantity = getCartQuantity(product._id);
          const stockStatus = getStockStatus(product.stock);
          
          return (
            <div 
              key={product._id} 
              onClick={() => handleProductClick(product)}
              className={`bg-white dark:bg-gray-900 rounded-xl p-4 border border-gray-200 dark:border-gray-700 transition-all duration-200 group relative ${
                product.stock === 0 
                  ? 'opacity-60 cursor-not-allowed' 
                  : 'hover:shadow-lg hover:border-red-300 dark:hover:border-red-600 cursor-pointer transform hover:-translate-y-1'
              }`}
            >
              {/* Stock Status Badge */}
              <div className={`absolute top-1 right-1 px-2 py-1 rounded-full text-xs font-medium ${stockStatus.bgColor} ${stockStatus.color}`}>
                {stockStatus.label}
              </div>

              {/* Cart Quantity Badge */}
              {quantity > 0 && (
                <div className="absolute top-1 left-2 bg-red-600 dark:bg-red-500 text-white rounded-full w-6 h-6 flex items-center justify-center text-xs font-bold">
                  {quantity}
                </div>
              )}

              <div className="space-y-2 py-3">
                {/* Product Info */}
                <div className="space-y-2">
                  <h3 className="font-semibold text-gray-800 dark:text-white line-clamp-2 group-hover:text-red-600 dark:group-hover:text-red-400 transition-colors">
                    {product.name}
                  </h3>
                  
                  <div className="flex items-center justify-between">
                    <div className="text-lg font-bold text-red-600 dark:text-red-400">
                      ₹{product.price.toLocaleString()}
                    </div>
                    <div className="text-sm text-gray-500 dark:text-gray-400">
                      Stock: {product.stock}
                    </div>
                  </div>

                  <div className="space-y-1 text-sm text-gray-600 dark:text-gray-400">
                    {product.brand && (
                      <div className="flex items-center justify-between">
                        <span>Brand:</span>
                        <span className="font-medium">{product.brand}</span>
                      </div>
                    )}
                    {product.model && (
                      <div className="flex items-center justify-between">
                        <span>Model:</span>
                        <span className="font-medium">{product.model}</span>
                      </div>
                    )}
                    {product.sku && (
                      <div className="flex items-center justify-between">
                        <span>SKU:</span>
                        <span className="font-mono text-xs bg-gray-100 dark:bg-gray-800 px-1 rounded">
                          {product.sku}
                        </span>
                      </div>
                    )}
                    {product.warranty && (
                      <div className="flex items-center justify-between text-xs text-green-600 dark:text-green-400">
                        <span>Warranty:</span>
                        <span>{product.warranty}</span>
                      </div>
                    )}
                  </div>
                </div>
              </div>
            </div>
          );
        })}
      </div>

      {/* No Products Found */}
      {filteredProducts.length === 0 && (
        <div className="text-center py-12">
          <Package className="w-16 h-16 text-gray-300 dark:text-gray-600 mx-auto mb-4" />
          <h3 className="text-lg font-medium text-gray-800 dark:text-white mb-2">No products found</h3>
          <p className="text-gray-500 dark:text-gray-400 mb-4">
            Try adjusting your search or filter criteria
          </p>
          {searchTerm.trim() && (
            <button
              onClick={handleAddNewProduct}
              className="bg-red-600 text-white px-4 py-2 rounded-lg hover:bg-red-700 transition-colors flex items-center space-x-2 mx-auto"
            >
              <Plus className="w-4 h-4" />
              <span>Add "{searchTerm}" as new product</span>
            </button>
          )}
        </div>
      )}

      {/* Product Add Dialog */}
      <ProductAddDialog
        isOpen={showProductDialog}
        onClose={() => setShowProductDialog(false)}
        initialName={searchTerm}
        onSave={handleSaveProduct}
      />
    </div>
  );
};

export default ProductGrid;