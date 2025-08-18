import { DatabaseService } from '../services/database';

export class DatabaseTester {
  private db: DatabaseService;

  constructor() {
    this.db = DatabaseService.getInstance({
      localDB: 'pos_local',
      remoteDB: 'http://localhost:5984',
      username: 'admin',
      password: 'admin'
    });
  }

  async runTests(): Promise<{ success: boolean; results: any[] }> {
    const results: any[] = [];

    try {
      // Test 1: Initialize database
      results.push(await this.testInitialization());
      
      // Test 2: Test local database operations
      results.push(await this.testLocalOperations());
      
      // Test 3: Test remote connectivity (if available)
      results.push(await this.testRemoteConnectivity());
      
      // Test 4: Create sample data
      results.push(await this.createSampleData());

      const allSuccess = results.every(r => r.success);
      return { success: allSuccess, results };
    } catch (error) {
      results.push({
        test: 'Database Tests',
        success: false,
        error: error.message
      });
      return { success: false, results };
    }
  }

  private async testInitialization(): Promise<any> {
    try {
      await this.db.initialize();
      return {
        test: 'Database Initialization',
        success: true,
        message: 'Database initialized successfully'
      };
    } catch (error) {
      return {
        test: 'Database Initialization',
        success: false,
        error: error.message
      };
    }
  }

  private async testLocalOperations(): Promise<any> {
    try {
      // Test creating a document
      const testDoc = {
        name: 'Test Item',
        type: 'test',
        timestamp: new Date().toISOString()
      };

      const created = await this.db.create('products', testDoc);
      
      // Test reading the document
      const retrieved = await this.db.findById('products', created._id);
      
      // Test updating the document
      retrieved.updated = true;
      const updated = await this.db.update('products', retrieved);
      
      // Test deleting the document
      await this.db.delete('products', updated._id);

      return {
        test: 'Local Database Operations',
        success: true,
        message: 'CRUD operations working correctly'
      };
    } catch (error) {
      return {
        test: 'Local Database Operations',
        success: false,
        error: error.message
      };
    }
  }

  private async testRemoteConnectivity(): Promise<any> {
    try {
      const isOnline = this.db.isOnlineStatus();
      
      if (isOnline) {
        return {
          test: 'Remote Connectivity',
          success: true,
          message: 'Connected to remote CouchDB'
        };
      } else {
        return {
          test: 'Remote Connectivity',
          success: true,
          message: 'Running in offline mode (no remote connection)',
          warning: true
        };
      }
    } catch (error) {
      return {
        test: 'Remote Connectivity',
        success: false,
        error: error.message
      };
    }
  }

  private async createSampleData(): Promise<any> {
    try {
      // Create sample company
      const company = await this.db.createCompany({
        name: 'Sample Electronics Store',
        address: '123 Main Street, City, Country',
        phone: '+1-234-567-8900',
        email: 'info@samplestore.com',
        settings: {
          currency: 'USD',
          timezone: 'UTC',
          dateFormat: 'DD/MM/YYYY',
          theme: 'light'
        }
      });

      // Create sample user
      const user = await this.db.createUser({
        username: 'admin',
        email: 'admin@samplestore.com',
        password: 'admin123',
        fullName: 'System Administrator',
        role: 'admin',
        companyId: company._id,
        permissions: ['all']
      });

      // Create sample categories
      const categories = await Promise.all([
        this.db.create('categories', {
          name: 'Smartphones',
          description: 'Mobile phones and smartphones',
          companyId: company._id,
          isActive: true
        }),
        this.db.create('categories', {
          name: 'Laptops',
          description: 'Laptop computers',
          companyId: company._id,
          isActive: true
        }),
        this.db.create('categories', {
          name: 'Accessories',
          description: 'Phone and computer accessories',
          companyId: company._id,
          isActive: true
        })
      ]);

      // Create sample products
      const products = await Promise.all([
        this.db.create('products', {
          name: 'iPhone 15 Pro',
          price: 999.99,
          stock: 50,
          category: 'Smartphones',
          brand: 'Apple',
          model: 'iPhone 15 Pro',
          sku: 'APL-IP15P-128',
          companyId: company._id,
          isActive: true,
          costPrice: 750,
          minStock: 5,
          maxStock: 100,
          warranty: '1 Year'
        }),
        this.db.create('products', {
          name: 'Samsung Galaxy S24',
          price: 899.99,
          stock: 30,
          category: 'Smartphones',
          brand: 'Samsung',
          model: 'Galaxy S24',
          sku: 'SAM-GS24-256',
          companyId: company._id,
          isActive: true,
          costPrice: 650,
          minStock: 5,
          maxStock: 80,
          warranty: '2 Years'
        }),
        this.db.create('products', {
          name: 'MacBook Pro 14"',
          price: 1999.99,
          stock: 15,
          category: 'Laptops',
          brand: 'Apple',
          model: 'MacBook Pro 14"',
          sku: 'APL-MBP14-512',
          companyId: company._id,
          isActive: true,
          costPrice: 1500,
          minStock: 2,
          maxStock: 25,
          warranty: '1 Year'
        })
      ]);

      // Create sample customers
      const customers = await Promise.all([
        this.db.create('customers', {
          name: 'John Doe',
          phone: '+1-555-0101',
          email: 'john@example.com',
          address: '456 Oak Street, City, Country',
          creditBalance: 0,
          creditLimit: 1000,
          loyaltyPoints: 150,
          companyId: company._id,
          isActive: true
        }),
        this.db.create('customers', {
          name: 'Jane Smith',
          phone: '+1-555-0102',
          email: 'jane@example.com',
          address: '789 Pine Avenue, City, Country',
          creditBalance: 50,
          creditLimit: 500,
          loyaltyPoints: 75,
          companyId: company._id,
          isActive: true
        })
      ]);

      return {
        test: 'Sample Data Creation',
        success: true,
        message: `Created sample data: 1 company, 1 user, ${categories.length} categories, ${products.length} products, ${customers.length} customers`,
        data: {
          company: company._id,
          user: user._id,
          categories: categories.length,
          products: products.length,
          customers: customers.length
        }
      };
    } catch (error) {
      return {
        test: 'Sample Data Creation',
        success: false,
        error: error.message
      };
    }
  }

  async clearAllData(): Promise<void> {
    const dbNames = ['users', 'products', 'categories', 'customers', 'sales', 'suppliers', 'companies', 'credit_transactions'];
    
    for (const dbName of dbNames) {
      try {
        const db = this.db.getDatabase(dbName);
        const allDocs = await db.allDocs({ include_docs: true });
        
        const deletePromises = allDocs.rows.map(row => {
          if (row.doc && !row.id.startsWith('_design/')) {
            return db.remove(row.doc._id, row.doc._rev);
          }
        }).filter(Boolean);
        
        await Promise.all(deletePromises);
        console.log(`Cleared ${deletePromises.length} documents from ${dbName}`);
      } catch (error) {
        console.error(`Error clearing ${dbName}:`, error);
      }
    }
  }

  getStatus(): { online: boolean; initialized: boolean } {
    return {
      online: this.db.isOnlineStatus(),
      initialized: this.db.isInitializedStatus()
    };
  }
}

// Export function to run tests from console
export const runDatabaseTests = async (): Promise<any> => {
  const tester = new DatabaseTester();
  const results = await tester.runTests();
  
  console.group('Database Test Results');
  results.results.forEach(result => {
    if (result.success) {
      console.log(`✅ ${result.test}: ${result.message}`);
      if (result.warning) {
        console.warn(`⚠️ ${result.message}`);
      }
    } else {
      console.error(`❌ ${result.test}: ${result.error}`);
    }
  });
  console.groupEnd();
  
  console.log(`Overall Status: ${results.success ? '✅ PASSED' : '❌ FAILED'}`);
  
  return results;
};

// Function to initialize database with sample data
export const initializeDatabaseWithSampleData = async (): Promise<any> => {
  const tester = new DatabaseTester();
  
  console.log('Initializing database with sample data...');
  
  // Clear existing data first
  await tester.clearAllData();
  
  // Run tests and create sample data
  const results = await tester.runTests();
  
  if (results.success) {
    console.log('✅ Database initialized successfully with sample data');
  } else {
    console.error('❌ Database initialization failed');
    console.error(results.results);
  }
  
  return results;
};

// Make functions available globally for debugging
if (typeof window !== 'undefined') {
  (window as any).runDatabaseTests = runDatabaseTests;
  (window as any).initializeDatabaseWithSampleData = initializeDatabaseWithSampleData;
  (window as any).DatabaseTester = DatabaseTester;
}