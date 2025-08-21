import React, { useState, useEffect } from 'react';
import { useAppState, useAppActions } from '../../../context/MainContext';
import { useAuth } from '../../../context/AuthContext';
import { Product, Category, Location } from '../../../types';
import { 
  Plus, 
  Search, 
  Edit3, 
  Trash2, 
  Package,
  DollarSign,
  Tag,
  AlertTriangle,
  TrendingDown,
  X,
  Save,
  Grid3X3,
  List,
  Filter
} from 'lucide-react';

const ProductManagement: React.FC = () => {
  const state = useAppState(s => s);
  const {
    loadProducts,
    createProduct,
    updateProduct,
    deleteProduct,
    loadCategories,
    createCategory,
    updateCategory,
    deleteCategory,
    searchProducts
  } = useAppActions();

  const { state: authState } = useAuth();

  const [searchTerm, setSearchTerm] = useState('');
  const [selectedCategory, setSelectedCategory] = useState('All');
  const [viewMode, setViewMode] = useState<'grid' | 'list'>('list');
  const [showAddProductModal, setShowAddProductModal] = useState(false);
  const [showEditProductModal, setShowEditProductModal] = useState(false);
  const [showAddCategoryModal, setShowAddCategoryModal] = useState(false);
  const [showEditCategoryModal, setShowEditCategoryModal] = useState(false);
  const [selectedProduct, setSelectedProduct] = useState<Product | null>(null);
  const [selectedCategoryData, setSelectedCategoryData] = useState<Category | null>(null);
  const [filteredProducts, setFilteredProducts] = useState<Product[]>([]);
  const [showFilters, setShowFilters] = useState(false);

  const [productForm, setProductForm] = useState({
  name: '',
  price: 0,
  costPrice: 0,
  stock: 0,
  category: '',
  brand: '',
  model: '',
  sku: '',
  locationId: '', // Add this
  supplierId: '',
  description: '',
  warranty: '',
  minStock: 5,
  maxStock: 100,
  specifications: {} as Record<string, string>
});

  const [categoryForm, setCategoryForm] = useState({
    name: '',
    description: ''
  });

  const [filters, setFilters] = useState({
    priceMin: '',
    priceMax: '',
    stockMin: '',
    stockMax: '',
    brand: '',
    supplier: '',
    lowStock: false,
    outOfStock: false
  });

  const getStockForLocation = (product: Product) => {
    if (product.stockLevels && state.currentLocationId) {
      const level = product.stockLevels.find(l => l.locationId === state.currentLocationId);
      return level ? level.quantity : 0;
    }
    return product.stock;
  };

  useEffect(() => {
    loadProducts();
    loadCategories();
  }, []);

  useEffect(() => {
    let filtered = state.products;

    // Search filter
    if (searchTerm.trim()) {
      filtered = searchProducts(searchTerm);
    }

    // Category filter
    if (selectedCategory !== 'All') {
      filtered = filtered.filter(p => p.category === selectedCategory);
    }

    if (state.currentLocationId) {
      filtered = filtered.filter(p =>
        p.stockLevels
          ? p.stockLevels.some(l => l.locationId === state.currentLocationId)
          : p.locationId === state.currentLocationId
      );
    }

    // Advanced filters
    if (filters.priceMin) {
      filtered = filtered.filter(p => p.price >= parseFloat(filters.priceMin));
    }
    if (filters.priceMax) {
      filtered = filtered.filter(p => p.price <= parseFloat(filters.priceMax));
    }
    if (filters.stockMin) {
      filtered = filtered.filter(p => getStockForLocation(p) >= parseInt(filters.stockMin));
    }
    if (filters.stockMax) {
      filtered = filtered.filter(p => getStockForLocation(p) <= parseInt(filters.stockMax));
    }
    if (filters.brand) {
      filtered = filtered.filter(p => p.brand?.toLowerCase().includes(filters.brand.toLowerCase()));
    }
    if (filters.supplier) {
      const supplier = state.suppliers.find(s => s.name.toLowerCase().includes(filters.supplier.toLowerCase()));
      if (supplier) {
        filtered = filtered.filter(p => p.supplierId === supplier._id);
      }
    }
    if (filters.lowStock) {
      filtered = filtered.filter(p => getStockForLocation(p) <= (p.minStock || 5));
    }
    if (filters.outOfStock) {
      filtered = filtered.filter(p => getStockForLocation(p) === 0);
    }

    setFilteredProducts(filtered);
  }, [searchTerm, selectedCategory, state.products, filters,state.currentLocationId]);

 const resetProductForm = () => {
  setProductForm({
    name: '',
    price: 0,
    costPrice: 0,
    stock: 0,
    category: state.categories.length > 1 ? state.categories[1] : '',
    brand: '',
    model: '',
    sku: '',
    locationId: state.currentLocationId || '', // Default to current location
    supplierId: '',
    description: '',
    warranty: '',
    minStock: 5,
    maxStock: 100,
    specifications: {}
  });
};

  const resetCategoryForm = () => {
    setCategoryForm({
      name: '',
      description: ''
    });
  };

  const handleAddProduct = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      await createProduct(productForm);
      setShowAddProductModal(false);
      resetProductForm();
    } catch (error: any) {
      console.error('Error adding product:', error);
    }
  };

  const handleEditProduct = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedProduct) return;
  
    try {
      await updateProduct(selectedProduct._id, {
        name: productForm.name,
        price: productForm.price,
        costPrice: productForm.costPrice,
        stock: productForm.stock,
        category: productForm.category,
        brand: productForm.brand,
        model: productForm.model,
        sku: productForm.sku,
        supplierId: productForm.supplierId,
        description: productForm.description,
        warranty: productForm.warranty,
        minStock: productForm.minStock,
        maxStock: productForm.maxStock,
        specifications: productForm.specifications
      });
      setShowEditProductModal(false);
      setSelectedProduct(null);
      resetProductForm();
    } catch (error: any) {
      console.error('Error updating product:', error);
    }
  };

  const handleDeleteProduct = async (productId: string) => {
    if (window.confirm('Are you sure you want to delete this product?')) {
      try {
        await deleteProduct(productId);
      } catch (error: any) {
        console.error('Error deleting product:', error);
      }
    }
  };

  const handleAddCategory = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      await createCategory({
        name: categoryForm.name,
        description: categoryForm.description
      });
      setShowAddCategoryModal(false);
      resetCategoryForm();
    } catch (error: any) {
      console.error('Error adding category:', error);
    }
  };

  const handleEditCategory = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedCategoryData) return;

    try {
      await updateCategory(selectedCategoryData._id, categoryForm);
      setShowEditCategoryModal(false);
      setSelectedCategoryData(null);
      resetCategoryForm();
    } catch (error: any) {
      console.error('Error updating category:', error);
    }
  };

  const handleDeleteCategory = async (categoryId: string) => {
    const productsInCategory = state.products.filter(p => p.category === selectedCategoryData?.name);
    if (productsInCategory.length > 0) {
      alert(`Cannot delete category. There are ${productsInCategory.length} products in this category.`);
      return;
    }

    if (window.confirm('Are you sure you want to delete this category?')) {
      try {
        await deleteCategory(categoryId);
        setSelectedCategory('All');
      } catch (error: any) {
        console.error('Error deleting category:', error);
      }
    }
  };

  const openEditProductModal = (product: Product) => {
    setSelectedProduct(product);
    setProductForm({
      name: product.name,
      price: product.price,
      costPrice: product.costPrice || 0,
      stock: getStockForLocation(product),
      category: product.category,
      brand: product.brand || '',
      model: product.model || '',
      sku: product.sku,
      locationId: product.locationId || state.currentLocationId || '', // Add this
      supplierId: product.supplierId || '',
      description: product.description || '',
      warranty: product.warranty || '',
      minStock: product.minStock || 5,
      maxStock: product.maxStock || 100,
      specifications: product.specifications || {}
    });
    setShowEditProductModal(true);
  };

  const formatCurrency = (amount: number) => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD'
    }).format(amount);
  };

  const getStockStatus = (product: Product) => {
    const stock = getStockForLocation(product);
    if (stock === 0) return { status: 'out', color: 'text-red-600 dark:text-red-400', bg: 'bg-red-100 dark:bg-red-900/30' };
    if (stock <= (product.minStock || 5)) return { status: 'low', color: 'text-yellow-600 dark:text-yellow-400', bg: 'bg-yellow-100 dark:bg-yellow-900/30' };
    return { status: 'good', color: 'text-green-600 dark:text-green-400', bg: 'bg-green-100 dark:bg-green-900/30' };
  };

  const getProductStats = () => {
    const totalProducts = state.products.length;
    const totalValue = state.products.reduce((sum, p) => sum + (p.price * getStockForLocation(p)), 0);
    const lowStockProducts = state.products.filter(p => getStockForLocation(p) <= (p.minStock || 5)).length;
    const outOfStockProducts = state.products.filter(p => getStockForLocation(p) === 0).length;

    return {
      totalProducts,
      totalValue,
      lowStockProducts,
      outOfStockProducts
    };
  };

  const stats = getProductStats();

  if (state.isLoading) {
    return (
      <div className="flex-1 p-6 bg-gray-50 dark:bg-gray-950 flex items-center justify-center">
        <div className="text-center">
          <div className="w-8 h-8 border-4 border-red-500 border-t-transparent rounded-full animate-spin mx-auto mb-4"></div>
          <p className="text-gray-600 dark:text-gray-400">Loading products...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="flex-1 p-6 bg-gray-50 dark:bg-gray-950">
      {/* Header */}
      <div className="mb-6">
        <h1 className="text-3xl font-bold text-gray-800 dark:text-white mb-2">Product Management</h1>
        <p className="text-gray-600 dark:text-gray-400">Manage your inventory and product catalog</p>
      </div>

      {/* Stats Cards */}
     <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-6">
  <div className="bg-white dark:bg-gray-900 rounded-xl p-6 border border-gray-200 dark:border-gray-700">
    <div className="flex items-center justify-between">
      <div>
        <p className="text-sm text-gray-600 dark:text-gray-400 mb-1">Total Products</p>
        <p className="text-2xl font-bold text-gray-800 dark:text-white">{stats.totalProducts}</p>
        {state.currentLocationId && (
          <p className="text-xs text-gray-500 dark:text-gray-400 mt-1">
            Current Location
          </p>
        )}
      </div>
      <div className="bg-blue-100 dark:bg-blue-900/30 p-3 rounded-lg">
        <Package className="w-6 h-6 text-blue-600 dark:text-blue-400" />
      </div>
    </div>
  </div>

  <div className="bg-white dark:bg-gray-900 rounded-xl p-6 border border-gray-200 dark:border-gray-700">
    <div className="flex items-center justify-between">
      <div>
        <p className="text-sm text-gray-600 dark:text-gray-400 mb-1">Inventory Value</p>
        <p className="text-2xl font-bold text-gray-800 dark:text-white">{formatCurrency(stats.totalValue)}</p>
        {state.currentLocationId && (
          <p className="text-xs text-gray-500 dark:text-gray-400 mt-1">
            Current Location
          </p>
        )}
      </div>
      <div className="bg-green-100 dark:bg-green-900/30 p-3 rounded-lg">
        <DollarSign className="w-6 h-6 text-green-600 dark:text-green-400" />
      </div>
    </div>
  </div>

  <div className="bg-white dark:bg-gray-900 rounded-xl p-6 border border-gray-200 dark:border-gray-700">
    <div className="flex items-center justify-between">
      <div>
        <p className="text-sm text-gray-600 dark:text-gray-400 mb-1">Low Stock Items</p>
        <p className="text-2xl font-bold text-gray-800 dark:text-white">{stats.lowStockProducts}</p>
        {state.currentLocationId && (
          <p className="text-xs text-gray-500 dark:text-gray-400 mt-1">
            Current Location
          </p>
        )}
      </div>
      <div className="bg-yellow-100 dark:bg-yellow-900/30 p-3 rounded-lg">
        <TrendingDown className="w-6 h-6 text-yellow-600 dark:text-yellow-400" />
      </div>
    </div>
  </div>

  <div className="bg-white dark:bg-gray-900 rounded-xl p-6 border border-gray-200 dark:border-gray-700">
    <div className="flex items-center justify-between">
      <div>
        <p className="text-sm text-gray-600 dark:text-gray-400 mb-1">Out of Stock</p>
        <p className="text-2xl font-bold text-gray-800 dark:text-white">{stats.outOfStockProducts}</p>
        {state.currentLocationId && (
          <p className="text-xs text-gray-500 dark:text-gray-400 mt-1">
            Current Location
          </p>
        )}
      </div>
      <div className="bg-red-100 dark:bg-red-900/30 p-3 rounded-lg">
        <AlertTriangle className="w-6 h-6 text-red-600 dark:text-red-400" />
      </div>
    </div>
  </div>
</div>

      {/* Actions Bar */}
      <div className="bg-white dark:bg-gray-900 rounded-xl p-4 mb-6 border border-gray-200 dark:border-gray-700">
        <div className="flex flex-col lg:flex-row gap-4 items-center justify-between">
          <div className="flex flex-col sm:flex-row gap-4 items-center flex-1">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-5 h-5" />
              <input
                type="text"
                placeholder="Search products..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-64 pl-10 pr-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white"
              />
            </div>

            <select
  required
  value={productForm.category}
  onChange={(e) => setProductForm(prev => ({ ...prev, category: e.target.value }))}
  className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white"
>
  <option value="">Select Category</option>
  {state.categories.filter(cat => cat !== 'All').map(category => (
    <option key={category} value={category}>
      {category}
    </option>
  ))}
</select>

            <button
              onClick={() => setShowFilters(!showFilters)}
              className="flex items-center space-x-2 px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-800"
            >
              <Filter className="w-4 h-4" />
              <span>Filters</span>
            </button>
          </div>

          <div className="flex items-center space-x-2">
            <div className="flex border border-gray-300 dark:border-gray-600 rounded-lg overflow-hidden">
              <button
                onClick={() => setViewMode('list')}
                className={`p-2 ${viewMode === 'list' ? 'bg-red-600 text-white' : 'text-gray-600 dark:text-gray-400'}`}
              >
                <List className="w-4 h-4" />
              </button>
              <button
                onClick={() => setViewMode('grid')}
                className={`p-2 ${viewMode === 'grid' ? 'bg-red-600 text-white' : 'text-gray-600 dark:text-gray-400'}`}
              >
                <Grid3X3 className="w-4 h-4" />
              </button>
            </div>

            <button
              onClick={() => setShowAddCategoryModal(true)}
              className="flex items-center space-x-2 bg-gray-600 text-white px-4 py-2 rounded-lg hover:bg-gray-700"
            >
              <Tag className="w-4 h-4" />
              <span>Add Category</span>
            </button>

            <button
              onClick={() => setShowAddProductModal(true)}
              className="flex items-center space-x-2 bg-red-600 text-white px-4 py-2 rounded-lg hover:bg-red-700"
            >
              <Plus className="w-4 h-4" />
              <span>Add Product</span>
            </button>
          </div>
        </div>

        {/* Advanced Filters */}
        {showFilters && (
          <div className="mt-4 p-4 bg-gray-50 dark:bg-gray-800 rounded-lg">
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Price Range
                </label>
                <div className="flex space-x-2">
                  <input
                    type="number"
                    placeholder="Min"
                    value={filters.priceMin}
                    onChange={(e) => setFilters(prev => ({ ...prev, priceMin: e.target.value }))}
                    className="w-full px-2 py-1 border border-gray-300 dark:border-gray-600 rounded focus:ring-1 focus:ring-red-500 dark:bg-gray-700 dark:text-white text-sm"
                  />
                  <input
                    type="number"
                    placeholder="Max"
                    value={filters.priceMax}
                    onChange={(e) => setFilters(prev => ({ ...prev, priceMax: e.target.value }))}
                    className="w-full px-2 py-1 border border-gray-300 dark:border-gray-600 rounded focus:ring-1 focus:ring-red-500 dark:bg-gray-700 dark:text-white text-sm"
                  />
                </div>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Stock Range
                </label>
                <div className="flex space-x-2">
                  <input
                    type="number"
                    placeholder="Min"
                    value={filters.stockMin}
                    onChange={(e) => setFilters(prev => ({ ...prev, stockMin: e.target.value }))}
                    className="w-full px-2 py-1 border border-gray-300 dark:border-gray-600 rounded focus:ring-1 focus:ring-red-500 dark:bg-gray-700 dark:text-white text-sm"
                  />
                  <input
                    type="number"
                    placeholder="Max"
                    value={filters.stockMax}
                    onChange={(e) => setFilters(prev => ({ ...prev, stockMax: e.target.value }))}
                    className="w-full px-2 py-1 border border-gray-300 dark:border-gray-600 rounded focus:ring-1 focus:ring-red-500 dark:bg-gray-700 dark:text-white text-sm"
                  />
                </div>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Brand
                </label>
                <input
                  type="text"
                  placeholder="Filter by brand"
                  value={filters.brand}
                  onChange={(e) => setFilters(prev => ({ ...prev, brand: e.target.value }))}
                  className="w-full px-2 py-1 border border-gray-300 dark:border-gray-600 rounded focus:ring-1 focus:ring-red-500 dark:bg-gray-700 dark:text-white text-sm"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Stock Status
                </label>
                <div className="space-y-1">
                  <label className="flex items-center">
                    <input
                      type="checkbox"
                      checked={filters.lowStock}
                      onChange={(e) => setFilters(prev => ({ ...prev, lowStock: e.target.checked }))}
                      className="mr-2 h-3 w-3 text-red-600 focus:ring-red-500 border-gray-300 rounded"
                    />
                    <span className="text-sm text-gray-700 dark:text-gray-300">Low Stock</span>
                  </label>
                  <label className="flex items-center">
                    <input
                      type="checkbox"
                      checked={filters.outOfStock}
                      onChange={(e) => setFilters(prev => ({ ...prev, outOfStock: e.target.checked }))}
                      className="mr-2 h-3 w-3 text-red-600 focus:ring-red-500 border-gray-300 rounded"
                    />
                    <span className="text-sm text-gray-700 dark:text-gray-300">Out of Stock</span>
                  </label>
                </div>
              </div>
            </div>

            <div className="mt-4 flex justify-end">
              <button
                onClick={() => setFilters({
                  priceMin: '',
                  priceMax: '',
                  stockMin: '',
                  stockMax: '',
                  brand: '',
                  supplier: '',
                  lowStock: false,
                  outOfStock: false
                })}
                className="px-4 py-2 text-gray-600 dark:text-gray-400 hover:text-gray-800 dark:hover:text-gray-200"
              >
                Clear Filters
              </button>
            </div>
          </div>
        )}
      </div>

      {/* Products Display */}
      {viewMode === 'list' ? (
        <div className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="bg-gray-50 dark:bg-gray-800">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                    Product
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                    SKU / Brand
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                    Category
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                    Price
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                    Stock
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                    Status
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody className="bg-white dark:bg-gray-900 divide-y divide-gray-200 dark:divide-gray-700">
                {filteredProducts.map((product) => {
                  const stockStatus = getStockStatus(product);
                  return (
                    <tr key={product._id} className="hover:bg-gray-50 dark:hover:bg-gray-800">
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="flex items-center">
                          <div className="w-10 h-10 bg-gray-100 dark:bg-gray-800 rounded-lg flex items-center justify-center">
                            <Package className="w-5 h-5 text-gray-600 dark:text-gray-400" />
                          </div>
                          <div className="ml-4">
                            <div className="text-sm font-medium text-gray-900 dark:text-white">
                              {product.name}
                            </div>
                            {product.model && (
                              <div className="text-sm text-gray-500 dark:text-gray-400">
                                {product.model}
                              </div>
                            )}
                          </div>
                        </div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="text-sm text-gray-900 dark:text-white">{product.sku}</div>
                        {product.brand && (
                          <div className="text-sm text-gray-500 dark:text-gray-400">{product.brand}</div>
                        )}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 dark:bg-gray-800 text-gray-800 dark:text-gray-200">
                          {product.category}
                        </span>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="text-sm font-medium text-gray-900 dark:text-white">
                          {formatCurrency(product.price)}
                        </div>
                        {product.costPrice && (
                          <div className="text-sm text-gray-500 dark:text-gray-400">
                            Cost: {formatCurrency(product.costPrice)}
                          </div>
                        )}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="text-sm font-medium text-gray-900 dark:text-white">
                          {getStockForLocation(product)} units
                        </div>
                        <div className="text-xs text-gray-500 dark:text-gray-400">
                          Min: {product.minStock || 5}
                        </div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${stockStatus.bg} ${stockStatus.color}`}>
                          {stockStatus.status === 'out' && 'Out of Stock'}
                          {stockStatus.status === 'low' && 'Low Stock'}
                          {stockStatus.status === 'good' && 'In Stock'}
                        </span>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">
                        <div className="flex space-x-2">
                          <button
                            onClick={() => openEditProductModal(product)}
                            className="text-blue-600 hover:text-blue-900 dark:text-blue-400 dark:hover:text-blue-300"
                            title="Edit Product"
                          >
                            <Edit3 className="w-4 h-4" />
                          </button>
                          <button
                            onClick={() => handleDeleteProduct(product._id)}
                            className="text-red-600 hover:text-red-900 dark:text-red-400 dark:hover:text-red-300"
                            title="Delete Product"
                          >
                            <Trash2 className="w-4 h-4" />
                          </button>
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>

          {filteredProducts.length === 0 && (
            <div className="text-center py-12">
              <Package className="w-12 h-12 text-gray-400 mx-auto mb-4" />
              <p className="text-gray-500 dark:text-gray-400">
                {searchTerm || selectedCategory !== 'All' ? 'No products found matching your criteria.' : 'No products yet. Add your first product!'}
              </p>
            </div>
          )}
        </div>
      ) : (
        // Grid View
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
          {filteredProducts.map((product) => {
            const stockStatus = getStockStatus(product);
            return (
              <div key={product._id} className="bg-white dark:bg-gray-900 rounded-xl border border-gray-200 dark:border-gray-700 overflow-hidden hover:shadow-lg transition-shadow">
                <div className="p-4">
                  <div className="flex items-center justify-between mb-3">
                    <span className={`inline-flex items-center px-2 py-1 rounded-full text-xs font-medium ${stockStatus.bg} ${stockStatus.color}`}>
                      {stockStatus.status === 'out' && 'Out of Stock'}
                      {stockStatus.status === 'low' && 'Low Stock'}
                      {stockStatus.status === 'good' && 'In Stock'}
                    </span>
                    <div className="flex space-x-1">
                      <button
                        onClick={() => openEditProductModal(product)}
                        className="p-1 text-gray-400 hover:text-blue-600 rounded"
                      >
                        <Edit3 className="w-4 h-4" />
                      </button>
                      <button
                        onClick={() => handleDeleteProduct(product._id)}
                        className="p-1 text-gray-400 hover:text-red-600 rounded"
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                    </div>
                  </div>

                  <div className="w-full h-32 bg-gray-100 dark:bg-gray-800 rounded-lg flex items-center justify-center mb-4">
                    <Package className="w-12 h-12 text-gray-400" />
                  </div>

                  <h3 className="text-sm font-medium text-gray-900 dark:text-white mb-1 line-clamp-2">
                    {product.name}
                  </h3>

                  <p className="text-xs text-gray-500 dark:text-gray-400 mb-2">
                    SKU: {product.sku}
                  </p>

                  <div className="flex items-center justify-between mb-2">
                    <span className="text-lg font-bold text-gray-900 dark:text-white">
                      {formatCurrency(product.price)}
                    </span>
                    <span className="text-sm text-gray-500 dark:text-gray-400">
                      Stock: {getStockForLocation(product)}
                    </span>
                  </div>

                  <div className="flex items-center justify-between">
                    <span className="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-gray-100 dark:bg-gray-800 text-gray-800 dark:text-gray-200">
                      {product.category}
                    </span>
                    {product.brand && (
                      <span className="text-xs text-gray-500 dark:text-gray-400">
                        {product.brand}
                      </span>
                    )}
                  </div>
                </div>
              </div>
            );
          })}

          {filteredProducts.length === 0 && (
            <div className="col-span-full text-center py-12">
              <Package className="w-12 h-12 text-gray-400 mx-auto mb-4" />
              <p className="text-gray-500 dark:text-gray-400">
                {searchTerm || selectedCategory !== 'All' ? 'No products found matching your criteria.' : 'No products yet. Add your first product!'}
              </p>
            </div>
          )}
        </div>
      )}

      {/* Add Product Modal */}
      {showAddProductModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white dark:bg-gray-900 rounded-xl p-6 w-full max-w-2xl mx-4 max-h-[90vh] overflow-y-auto">
            <div className="flex justify-between items-center mb-4">
              <h3 className="text-lg font-semibold text-gray-800 dark:text-white">Add New Product</h3>
              <button
                onClick={() => {
                  setShowAddProductModal(false);
                  resetProductForm();
                }}
                className="p-1 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-full"
              >
                <X className="w-5 h-5 text-gray-500 dark:text-gray-400" />
              </button>
            </div>

            <form onSubmit={handleAddProduct} className="space-y-4">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Product Name *
                  </label>
                  <input
                    type="text"
                    required
                    value={productForm.name}
                    onChange={(e) => setProductForm(prev => ({ ...prev, name: e.target.value }))}
                    className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    SKU *
                  </label>
                  <input
                    type="text"
                    required
                    value={productForm.sku}
                    onChange={(e) => setProductForm(prev => ({ ...prev, sku: e.target.value }))}
                    className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Category *
                  </label>
                  <select
  required
  value={productForm.category}
  onChange={(e) => setProductForm(prev => ({ ...prev, category: e.target.value }))}
  className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white"
>
  <option value="">Select Category</option>
  {state.categories.filter(cat => cat !== 'All').map(category => (
    <option key={category} value={category}>
      {category}
    </option>
  ))}
</select>
                </div>
                
<div>
  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
    Location *
  </label>
  <select
    required
    value={productForm.locationId}
    onChange={(e) => setProductForm(prev => ({ ...prev, locationId: e.target.value }))}
    className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white"
  >
    <option value="">Select Location</option>
    {authState.company?.locations?.filter((loc: Location) => loc.isActive).map((location: Location) => (
      <option key={location._id} value={location._id}>
        {location.name}
      </option>
    ))}
  </select>
</div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Brand
                  </label>
                  <input
                    type="text"
                    value={productForm.brand}
                    onChange={(e) => setProductForm(prev => ({ ...prev, brand: e.target.value }))}
                    className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Model
                  </label>
                  <input
                    type="text"
                    value={productForm.model}
                    onChange={(e) => setProductForm(prev => ({ ...prev, model: e.target.value }))}
                    className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Selling Price *
                  </label>
                  <input
                    type="number"
                    required
                    min="0"
                    step="0.01"
                    value={productForm.price}
                    onChange={(e) => setProductForm(prev => ({ ...prev, price: parseFloat(e.target.value) || 0 }))}
                    className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Cost Price
                  </label>
                  <input
                    type="number"
                    min="0"
                    step="0.01"
                    value={productForm.costPrice}
                    onChange={(e) => setProductForm(prev => ({ ...prev, costPrice: parseFloat(e.target.value) || 0 }))}
                    className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Initial Stock *
                  </label>
                  <input
                    type="number"
                    required
                    min="0"
                    value={productForm.stock}
                    onChange={(e) => setProductForm(prev => ({ ...prev, stock: parseInt(e.target.value) || 0 }))}
                    className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Minimum Stock Alert
                  </label>
                  <input
                    type="number"
                    min="0"
                    value={productForm.minStock}
                    onChange={(e) => setProductForm(prev => ({ ...prev, minStock: parseInt(e.target.value) || 5 }))}
                    className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Maximum Stock
                  </label>
                  <input
                    type="number"
                    min="0"
                    value={productForm.maxStock}
                    onChange={(e) => setProductForm(prev => ({ ...prev, maxStock: parseInt(e.target.value) || 100 }))}
                    className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Supplier
                  </label>
                  <select
                    value={productForm.supplierId}
                    onChange={(e) => setProductForm(prev => ({ ...prev, supplierId: e.target.value }))}
                    className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white"
                  >
                    <option value="">Select Supplier</option>
                    {state.suppliers.map((supplier) => (
                      <option key={supplier._id} value={supplier._id}>
                        {supplier.name}
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Warranty
                  </label>
                  <input
                    type="text"
                    value={productForm.warranty}
                    onChange={(e) => setProductForm(prev => ({ ...prev, warranty: e.target.value }))}
                    placeholder="e.g., 1 Year, 6 Months"
                    className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white"
                  />
                </div>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Description
                </label>
                <textarea
                  value={productForm.description}
                  onChange={(e) => setProductForm(prev => ({ ...prev, description: e.target.value }))}
                  rows={3}
                  className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white"
                />
              </div>

              <div className="flex space-x-3 pt-4">
                <button
                  type="button"
                  onClick={() => {
                    setShowAddProductModal(false);
                    resetProductForm();
                  }}
                  className="flex-1 px-4 py-2 border border-gray-300 dark:border-gray-600 text-gray-700 dark:text-gray-300 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-800"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={state.isLoading}
                  className="flex-1 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 disabled:opacity-50 flex items-center justify-center space-x-2"
                >
                  <Save className="w-4 h-4" />
                  <span>Save Product</span>
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Edit Product Modal */}
      {showEditProductModal && selectedProduct && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white dark:bg-gray-900 rounded-xl p-6 w-full max-w-2xl mx-4 max-h-[90vh] overflow-y-auto">
            <div className="flex justify-between items-center mb-4">
              <h3 className="text-lg font-semibold text-gray-800 dark:text-white">Edit Product</h3>
              <button
                onClick={() => {
                  setShowEditProductModal(false);
                  setSelectedProduct(null);
                  resetProductForm();
                }}
                className="p-1 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-full"
              >
                <X className="w-5 h-5 text-gray-500 dark:text-gray-400" />
              </button>
            </div>

            <form onSubmit={handleEditProduct} className="space-y-4">
              {/* Same form fields as Add Product Modal */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Product Name *
                  </label>
                  <input
                    type="text"
                    required
                    value={productForm.name}
                    onChange={(e) => setProductForm(prev => ({ ...prev, name: e.target.value }))}
                    className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    SKU *
                  </label>
                  <input
                    type="text"
                    required
                    value={productForm.sku}
                    onChange={(e) => setProductForm(prev => ({ ...prev, sku: e.target.value }))}
                    className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Category *
                  </label>
                  <select
  required
  value={productForm.category}
  onChange={(e) => setProductForm(prev => ({ ...prev, category: e.target.value }))}
  className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white"
>
  <option value="">Select Category</option>
  {state.categories.filter(cat => cat !== 'All').map(category => (
    <option key={category} value={category}>
      {category}
    </option>
  ))}
</select>
                </div>
                // Add this after the Category field in both Add and Edit modals
<div>
  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
    Location *
  </label>
  <select
    required
    value={productForm.locationId}
    onChange={(e) => setProductForm(prev => ({ ...prev, locationId: e.target.value }))}
    className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white"
  >
    <option value="">Select Location</option>
    {authState.company?.locations?.filter((loc: Location) => loc.isActive).map((location: Location) => (
      <option key={location._id} value={location._id}>
        {location.name}
      </option>
    ))}
  </select>
</div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Brand
                  </label>
                  <input
                    type="text"
                    value={productForm.brand}
                    onChange={(e) => setProductForm(prev => ({ ...prev, brand: e.target.value }))}
                    className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Selling Price *
                  </label>
                  <input
                    type="number"
                    required
                    min="0"
                    step="0.01"
                    value={productForm.price}
                    onChange={(e) => setProductForm(prev => ({ ...prev, price: parseFloat(e.target.value) || 0 }))}
                    className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Current Stock *
                  </label>
                  <input
                    type="number"
                    required
                    min="0"
                    value={productForm.stock}
                    onChange={(e) => setProductForm(prev => ({ ...prev, stock: parseInt(e.target.value) || 0 }))}
                    className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white"
                  />
                </div>
              </div>

              <div className="flex space-x-3 pt-4">
                <button
                  type="button"
                  onClick={() => {
                    setShowEditProductModal(false);
                    setSelectedProduct(null);
                    resetProductForm();
                  }}
                  className="flex-1 px-4 py-2 border border-gray-300 dark:border-gray-600 text-gray-700 dark:text-gray-300 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-800"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={state.isLoading}
                  className="flex-1 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 disabled:opacity-50 flex items-center justify-center space-x-2"
                >
                  <Save className="w-4 h-4" />
                  <span>Update Product</span>
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Add Category Modal */}
      {showAddCategoryModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white dark:bg-gray-900 rounded-xl p-6 w-full max-w-md mx-4">
            <div className="flex justify-between items-center mb-4">
              <h3 className="text-lg font-semibold text-gray-800 dark:text-white">Add New Category</h3>
              <button
                onClick={() => {
                  setShowAddCategoryModal(false);
                  resetCategoryForm();
                }}
                className="p-1 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-full"
              >
                <X className="w-5 h-5 text-gray-500 dark:text-gray-400" />
              </button>
            </div>

            <form onSubmit={handleAddCategory} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Category Name *
                </label>
                <input
                  type="text"
                  required
                  value={categoryForm.name}
                  onChange={(e) => setCategoryForm(prev => ({ ...prev, name: e.target.value }))}
                  className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white"
                />
              </div>

              <div>
  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
    Location *
  </label>
  <select
    required
    value={productForm.locationId}
    onChange={(e) => setProductForm(prev => ({ ...prev, locationId: e.target.value }))}
    className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white"
  >
    <option value="">Select Location</option>
    {authState.company?.locations?.filter((loc: Location) => loc.isActive).map((location: Location) => (
      <option key={location._id} value={location._id}>
        {location.name}
      </option>
    ))}
  </select>
</div>

              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Description
                </label>
                <textarea
                  value={categoryForm.description}
                  onChange={(e) => setCategoryForm(prev => ({ ...prev, description: e.target.value }))}
                  rows={3}
                  className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white"
                />
              </div>

              <div className="flex space-x-3 pt-4">
                <button
                  type="button"
                  onClick={() => {
                    setShowAddCategoryModal(false);
                    resetCategoryForm();
                  }}
                  className="flex-1 px-4 py-2 border border-gray-300 dark:border-gray-600 text-gray-700 dark:text-gray-300 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-800"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={state.isLoading}
                  className="flex-1 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 disabled:opacity-50 flex items-center justify-center space-x-2"
                >
                  <Save className="w-4 h-4" />
                  <span>Save Category</span>
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Edit Category Modal */}
      {showEditCategoryModal && selectedCategoryData && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white dark:bg-gray-900 rounded-xl p-6 w-full max-w-md mx-4">
            <div className="flex justify-between items-center mb-4">
              <h3 className="text-lg font-semibold text-gray-800 dark:text-white">Edit Category</h3>
              <button
                onClick={() => {
                  setShowEditCategoryModal(false);
                  setSelectedCategoryData(null);
                  resetCategoryForm();
                }}
                className="p-1 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-full"
              >
                <X className="w-5 h-5 text-gray-500 dark:text-gray-400" />
              </button>
            </div>

            <form onSubmit={handleEditCategory} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Category Name *
                </label>
                <input
                  type="text"
                  required
                  value={categoryForm.name}
                  onChange={(e) => setCategoryForm(prev => ({ ...prev, name: e.target.value }))}
                  className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                  Description
                </label>
                <textarea
                  value={categoryForm.description}
                  onChange={(e) => setCategoryForm(prev => ({ ...prev, description: e.target.value }))}
                  rows={3}
                  className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-red-500 dark:bg-gray-800 dark:text-white"
                />
              </div>

              <div className="flex space-x-3 pt-4">
                <button
                  type="button"
                  onClick={() => {
                    setShowEditCategoryModal(false);
                    setSelectedCategoryData(null);
                    resetCategoryForm();
                  }}
                  className="flex-1 px-4 py-2 border border-gray-300 dark:border-gray-600 text-gray-700 dark:text-gray-300 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-800"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={state.isLoading}
                  className="flex-1 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 disabled:opacity-50 flex items-center justify-center space-x-2"
                >
                  <Save className="w-4 h-4" />
                  <span>Update Category</span>
                </button>
              </div>
            </form>

            <div className="mt-4 pt-4 border-t border-gray-200 dark:border-gray-700">
              <button
                onClick={() => handleDeleteCategory(selectedCategoryData._id)}
                className="w-full flex items-center justify-center space-x-2 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700"
              >
                <Trash2 className="w-4 h-4" />
                <span>Delete Category</span>
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default ProductManagement;