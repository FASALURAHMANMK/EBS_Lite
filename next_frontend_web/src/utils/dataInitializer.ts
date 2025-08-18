import { DatabaseService } from '../services/database';

export class DataInitializer {
  private db: DatabaseService;

  constructor() {
    this.db = DatabaseService.getInstance();
  }

  async checkAndInitializeSampleData(companyId: string): Promise<void> {
    try {
      console.log('Checking if sample data needs to be created...');
      
      // Check if we have any products
      const products = await this.db.find('products', {
        selector: { companyId, isActive: true },
        limit: 1
      });

      if (products.length === 0) {
        console.log('No products found, creating sample data...');
        await this.createSampleData(companyId);
      } else {
        console.log(`Found ${products.length} existing products, skipping sample data creation`);
      }
    } catch (error) {
      console.error('Error checking/creating sample data:', error);
    }
  }

  private async createSampleData(companyId: string): Promise<void> {
    try {
      console.log('Creating sample data for company:', companyId);

      // Create categories first
      const categories = [
        { name: 'Smartphones', description: 'Mobile phones and smartphones' },
        { name: 'Laptops', description: 'Laptop computers' },
        { name: 'Accessories', description: 'Phone and computer accessories' },
        { name: 'Tablets', description: 'Tablet computers' }
      ];

      const createdCategories = [];
      for (const cat of categories) {
        try {
          const category = await this.db.create('categories', {
            ...cat,
            companyId,
            isActive: true
          });
          createdCategories.push(category);
          console.log(`Created category: ${cat.name}`);
        } catch (error) {
          console.warn(`Failed to create category ${cat.name}:`, error);
        }
      }

      // Create sample products
      const products = [
        {
          name: 'iPhone 15 Pro',
          price: 999.99,
          stock: 50,
          category: 'Smartphones',
          brand: 'Apple',
          model: 'iPhone 15 Pro',
          sku: 'APL-IP15P-128',
          costPrice: 750.00,
          minStock: 5,
          maxStock: 100,
          warranty: '1 Year',
          description: 'Latest iPhone with Pro camera system'
        },
        {
          name: 'Samsung Galaxy S24',
          price: 899.99,
          stock: 30,
          category: 'Smartphones',
          brand: 'Samsung',
          model: 'Galaxy S24',
          sku: 'SAM-GS24-256',
          costPrice: 650.00,
          minStock: 5,
          maxStock: 80,
          warranty: '2 Years',
          description: 'Premium Android smartphone'
        },
        {
          name: 'MacBook Pro 14"',
          price: 1999.99,
          stock: 15,
          category: 'Laptops',
          brand: 'Apple',
          model: 'MacBook Pro 14"',
          sku: 'APL-MBP14-512',
          costPrice: 1500.00,
          minStock: 2,
          maxStock: 25,
          warranty: '1 Year',
          description: 'Professional laptop with M3 chip'
        },
        {
          name: 'Dell XPS 13',
          price: 1299.99,
          stock: 20,
          category: 'Laptops',
          brand: 'Dell',
          model: 'XPS 13',
          sku: 'DELL-XPS13-512',
          costPrice: 950.00,
          minStock: 3,
          maxStock: 30,
          warranty: '1 Year',
          description: 'Ultrabook with premium design'
        },
        {
          name: 'AirPods Pro',
          price: 249.99,
          stock: 100,
          category: 'Accessories',
          brand: 'Apple',
          model: 'AirPods Pro',
          sku: 'APL-APP-PRO',
          costPrice: 180.00,
          minStock: 10,
          maxStock: 200,
          warranty: '1 Year',
          description: 'Wireless earbuds with noise cancellation'
        },
        {
          name: 'iPad Air',
          price: 599.99,
          stock: 25,
          category: 'Tablets',
          brand: 'Apple',
          model: 'iPad Air',
          sku: 'APL-IPADAIR-64',
          costPrice: 450.00,
          minStock: 5,
          maxStock: 50,
          warranty: '1 Year',
          description: 'Versatile tablet for work and play'
        }
      ];

      const createdProducts = [];
      for (const prod of products) {
        try {
          const product = await this.db.create('products', {
            ...prod,
            companyId,
            isActive: true
          });
          createdProducts.push(product);
          console.log(`Created product: ${prod.name}`);
        } catch (error) {
          console.warn(`Failed to create product ${prod.name}:`, error);
        }
      }

      // Create sample customers
      const customers = [
        {
          name: 'John Doe',
          phone: '+1-555-0101',
          email: 'john@example.com',
          address: '123 Main Street, City, Country',
          creditBalance: 0,
          creditLimit: 1000,
          loyaltyPoints: 150
        },
        {
          name: 'Jane Smith',
          phone: '+1-555-0102',
          email: 'jane@example.com',
          address: '456 Oak Avenue, City, Country',
          creditBalance: 50,
          creditLimit: 500,
          loyaltyPoints: 75
        },
        {
          name: 'Mike Johnson',
          phone: '+1-555-0103',
          email: 'mike@example.com',
          address: '789 Pine Road, City, Country',
          creditBalance: 0,
          creditLimit: 2000,
          loyaltyPoints: 300
        }
      ];

      const createdCustomers = [];
      for (const cust of customers) {
        try {
          const customer = await this.db.create('customers', {
            ...cust,
            companyId,
            isActive: true
          });
          createdCustomers.push(customer);
          console.log(`Created customer: ${cust.name}`);
        } catch (error) {
          console.warn(`Failed to create customer ${cust.name}:`, error);
        }
      }

      console.log(`Sample data creation complete:
        - Categories: ${createdCategories.length}/${categories.length}
        - Products: ${createdProducts.length}/${products.length}
        - Customers: ${createdCustomers.length}/${customers.length}`);

    } catch (error) {
      console.error('Error creating sample data:', error);
      throw error;
    }
  }

  async clearAllCompanyData(companyId: string): Promise<void> {
    console.log('Clearing all data for company:', companyId);
    
    const collections = ['products', 'categories', 'customers', 'sales', 'suppliers', 'credit_transactions'];
    
    for (const collection of collections) {
      try {
        const docs = await this.db.find(collection, {
          selector: { companyId }
        });
        
        console.log(`Found ${docs.length} documents in ${collection}`);
        
        for (const doc of docs) {
          await this.db.delete(collection, doc._id);
        }
        
        console.log(`Cleared ${docs.length} documents from ${collection}`);
      } catch (error) {
        console.warn(`Error clearing ${collection}:`, error);
      }
    }
  }
}

// Function to be called from console or initialization
export const initializeSampleData = async (companyId: string): Promise<void> => {
  const initializer = new DataInitializer();
  await initializer.checkAndInitializeSampleData(companyId);
};

export const clearCompanyData = async (companyId: string): Promise<void> => {
  const initializer = new DataInitializer();
  await initializer.clearAllCompanyData(companyId);
};

// Make available globally for debugging
if (typeof window !== 'undefined') {
  (window as any).initializeSampleData = initializeSampleData;
  (window as any).clearCompanyData = clearCompanyData;
}