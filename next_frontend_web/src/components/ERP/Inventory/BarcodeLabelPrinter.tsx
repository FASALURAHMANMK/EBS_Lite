import React, { useState } from 'react';
import { useAppState } from '../../../context/MainContext';

const BarcodeLabelPrinter: React.FC = () => {
  const state = useAppState(s => s);
  const [productId, setProductId] = useState('');

  const selectedProduct = state.products.find(p => p._id === productId);

  return (
    <div className="p-4 max-w-xl">
      <h1 className="text-2xl font-bold mb-4">Barcode / Label Printing</h1>
      <div className="space-y-4">
        <div>
          <label className="block text-sm mb-1">Product</label>
          <select value={productId} onChange={e => setProductId(e.target.value)} className="w-full border px-2 py-1">
            <option value="">Select product</option>
            {state.products.map(p => (
              <option key={p._id} value={p._id}>{p.name}</option>
            ))}
          </select>
        </div>
        {selectedProduct && (
          <div className="space-y-2">
            {selectedProduct.barcodes?.map(b => (
              <div key={b.barcode} className="border p-2 flex items-center justify-between">
                <span>{b.barcode}</span>
                <button onClick={() => window.print()} className="px-2 py-1 bg-blue-600 text-white rounded text-xs">Print</button>
              </div>
            ))}
            {!selectedProduct.barcodes && <p className="text-sm text-gray-500">No barcodes found.</p>}
          </div>
        )}
      </div>
    </div>
  );
};

export default BarcodeLabelPrinter;
