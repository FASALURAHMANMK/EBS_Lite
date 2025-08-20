import React, { useEffect, useState } from 'react';
import { useRouter } from 'next/router';
import { products, inventory } from '../../../services';
import { Product, ProductStockLevel } from '../../../types';

const ProductDetail: React.FC = () => {
  const router = useRouter();
  const { id } = router.query;
  const [product, setProduct] = useState<Product | null>(null);
  const [stock, setStock] = useState<ProductStockLevel[]>([]);

  useEffect(() => {
    if (id) {
      products.getProduct(id as string).then(setProduct);
      inventory.getProductStock(id as string).then(setStock).catch(() => {});
    }
  }, [id]);

  if (!product) return <div className="p-4">Loading...</div>;

  return (
    <div className="p-4 space-y-6">
      <div>
        <h1 className="text-2xl font-bold mb-2">{product.name}</h1>
        <p className="text-gray-500">SKU: {product.sku}</p>
      </div>

      <div>
        <h2 className="text-xl font-semibold mb-2">Details</h2>
        <p>Price: {product.price}</p>
        {product.description && <p className="mt-2">{product.description}</p>}
      </div>

      {product.attributes && product.attributes.length > 0 && (
        <div>
          <h2 className="text-xl font-semibold mb-2">Attributes</h2>
          <ul className="list-disc pl-5 space-y-1">
            {product.attributes.map(attr => (
              <li key={attr.attributeId}>
                {attr.definition?.name || attr.attributeId}: {attr.value}
              </li>
            ))}
          </ul>
        </div>
      )}

      {stock.length > 0 && (
        <div>
          <h2 className="text-xl font-semibold mb-2">Stock by Location</h2>
          <table className="min-w-full border">
            <thead>
              <tr>
                <th className="px-2 py-1 border">Location</th>
                <th className="px-2 py-1 border">Quantity</th>
              </tr>
            </thead>
            <tbody>
              {stock.map(s => (
                <tr key={s.locationId}>
                  <td className="border px-2 py-1">{s.locationId}</td>
                  <td className="border px-2 py-1 text-right">{s.quantity}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
};

export default ProductDetail;
