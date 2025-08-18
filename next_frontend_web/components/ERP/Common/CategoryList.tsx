import React, { useState, useEffect } from 'react';
import { useApp } from '../../../context/MainContext';
import { Search, Plus, X, Tag } from 'lucide-react';

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

// Category Add Dialog
const CategoryAddDialog: React.FC<{
  isOpen: boolean;
  onClose: () => void;
  initialName: string;
  onSave: (category: string) => void;
}> = ({ isOpen, onClose, initialName, onSave }) => {
  const [categoryName, setCategoryName] = useState(initialName);
  const [description, setDescription] = useState('');

  useEffect(() => {
    setCategoryName(initialName);
  }, [initialName]);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (categoryName.trim()) {
      onSave(categoryName.trim());
      setCategoryName('');
      setDescription('');
      onClose();
    }
  };

  return (
    <Modal isOpen={isOpen} onClose={onClose} title="Add New Category">
      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
            Category Name *
          </label>
          <input
            type="text"
            value={categoryName}
            onChange={(e) => setCategoryName(e.target.value)}
            className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none focus:border-red-500 bg-white dark:bg-gray-800 text-gray-900 dark:text-white"
            placeholder="Enter category name"
            required
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
            Description (Optional)
          </label>
          <textarea
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none focus:border-red-500 bg-white dark:bg-gray-800 text-gray-900 dark:text-white"
            placeholder="Enter category description"
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
            Add Category
          </button>
        </div>
      </form>
    </Modal>
  );
};

const CategoryList: React.FC = () => {
  const { state, dispatch } = useApp();
  const [searchTerm, setSearchTerm] = useState('');
  const [showCategoryDropdown, setShowCategoryDropdown] = useState(false);
  const [showCategoryDialog, setShowCategoryDialog] = useState(false);
  const [filteredCategories, setFilteredCategories] = useState(state.categories);

  // Filter categories based on search term
  useEffect(() => {
    if (searchTerm.trim() === '') {
      setFilteredCategories(state.categories);
    } else {
      const filtered = state.categories.filter(category =>
        category.toLowerCase().includes(searchTerm.toLowerCase())
      );
      setFilteredCategories(filtered);
    }
  }, [searchTerm, state.categories]);


  const handleAddNewCategory = () => {
    setShowCategoryDialog(true);
    setShowCategoryDropdown(false);
  };

  const handleSaveCategory = (categoryName: string) => {
    if (!state.categories.includes(categoryName)) {
      dispatch({ type: 'ADD_CATEGORY', payload: categoryName });
      dispatch({ type: 'SET_CATEGORY', payload: categoryName });
    }
  };

  const getProductCountForCategory = (category: string) => {
    return category === 'All' 
      ? state.products.length 
      : state.products.filter(p => p.category === category).length;
  };

  const hasNoResults = searchTerm.trim() && filteredCategories.length === 0;

  return (
    <div className="w-72 bg-white dark:bg-gray-900 border-r border-gray-200 dark:border-gray-700 p-4 overflow-y-auto">
      <div className="mb-4">
        <h2 className="text-lg font-semibold text-gray-800 dark:text-white mb-2">Categories</h2>
        <div className="text-sm text-gray-500 dark:text-gray-400">
          {state.products.length} products available
        </div>
      </div>

      {/* Category Search Bar */}
      <div className="mb-4 relative">
        <div className="relative">
          <Search className="absolute left-3 top-3 w-4 h-4 text-gray-400" />
          <input
            type="text"
            placeholder="Search categories..."
            value={searchTerm}
            onChange={(e) => {
              setSearchTerm(e.target.value);
              setShowCategoryDropdown(e.target.value.length > 0);
            }}
            onFocus={() => searchTerm.length > 0 && setShowCategoryDropdown(true)}
            className="w-full pl-10 pr-8 py-2.5 border border-gray-300 dark:border-gray-600 rounded-lg focus:outline-none focus:border-red-500 dark:focus:border-red-400 bg-white dark:bg-gray-800 text-gray-900 dark:text-white text-sm"
          />
        </div>

        {/* Category Search Dropdown */}
        {showCategoryDropdown && (
          <div className="absolute top-full left-0 right-0 mt-1 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-600 rounded-lg shadow-lg z-10 max-h-48 overflow-y-auto">     
            {/* Add New Category Option */}
            {hasNoResults && (
              <div 
                onClick={handleAddNewCategory}
                className="p-3 hover:bg-gray-50 dark:hover:bg-gray-700 cursor-pointer border-t dark:border-gray-600 bg-gray-50 dark:bg-gray-800"
              >
                <div className="flex items-center space-x-2 text-red-600 dark:text-red-400">
                  <Plus className="w-4 h-4" />
                  <span className="text-sm font-medium">Add "{searchTerm}" as new category</span>
                </div>
              </div>
            )}
          </div>
        )}
      </div>
      
      {/* Categories List */}
      <div className="space-y-2">
        {filteredCategories.map((category) => {
          const isSelected = state.selectedCategory === category;
          const productCount = getProductCountForCategory(category);
          
          return (
            <button
              key={category}
              onClick={() => dispatch({ type: 'SET_CATEGORY', payload: category })}
              className={`w-full text-left p-3 rounded-xl font-medium transition-all duration-200 group ${
                isSelected
                  ? 'bg-gradient-to-r from-red-500 to-red-600 text-white shadow-lg transform scale-105'
                  : 'bg-gray-50 dark:bg-gray-800 text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700 hover:shadow-md'
              }`}
            >
              <div className="flex items-center justify-between">
                <div className="flex items-center space-x-3">
                  <Tag className={`w-4 h-4 ${
                    isSelected 
                      ? 'text-white' 
                      : 'text-gray-500 dark:text-gray-400'
                  }`} />
                  <span className={`text-sm font-medium ${
                    isSelected 
                      ? 'text-white' 
                      : 'text-gray-700 dark:text-gray-300'
                  }`}>
                    {category}
                  </span>
                </div>
                <div className={`text-xs px-2 py-1 rounded-full ${
                  isSelected 
                    ? 'bg-white/20 text-white' 
                    : 'bg-gray-200 dark:bg-gray-700 text-gray-600 dark:text-gray-400'
                }`}>
                  {productCount}
                </div>
              </div>
            </button>
          );
        })}
        {/* No Category Found */}
      {filteredCategories.length === 0 && (
        <div className="text-center py-14">
          <Tag className="w-12 h-12 text-gray-300 dark:text-gray-600 mx-auto mb-3" />
          <h3 className="text-lg font-medium text-gray-800 dark:text-white mb-3">No categoy found</h3>
          <p className="text-gray-500 dark:text-gray-400 mb-4">
            Try adjusting your search term
          </p>
          {searchTerm.trim() && (
            <button
              onClick={handleAddNewCategory}
              className="bg-red-600 text-white px-4 py-2 rounded-lg hover:bg-red-700 transition-colors flex items-center space-x-1 mx-auto"
            >
              <Plus className="w-3 h-3" />
              <span>Add "{searchTerm}" as new category</span>
            </button>
          )}
        </div>
      )}
      </div>

      {/* Category Add Dialog */}
      <CategoryAddDialog
        isOpen={showCategoryDialog}
        onClose={() => setShowCategoryDialog(false)}
        initialName={searchTerm}
        onSave={handleSaveCategory}
      />
    </div>
  );
};

export default CategoryList;