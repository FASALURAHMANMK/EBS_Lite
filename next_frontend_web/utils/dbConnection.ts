import { DatabaseService } from '../services/database';

export async function testDatabaseConnection() {
  try {
    const config = {
      localDB: 'pos_local',
      remoteDB: 'http://127.0.0.1:5984', // Use your actual URL
      username: 'admin',
      password: 'admin'
    };

    console.log('🧪 Testing database connection...');
    
    const db = DatabaseService.getInstance(config);
    await db.initialize();
    
    // Wait a moment for initialization
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    // Test basic operations
    const testDoc = {
      _id: `test_${Date.now()}`,
      type: 'connection_test',
      timestamp: new Date().toISOString()
    };
    
    const created = await db.create('products', testDoc);
    await db.delete('products', created._id);
    
    return {
      success: true,
      online: db.isOnlineStatus(),
      initialized: db.isInitializedStatus(),
      message: 'Database connection successful'
    };
  } catch (error: any) {
    return {
      success: false,
      online: false,
      initialized: false,
      message: `Connection failed: ${error.message}`
    };
  }
}

if (typeof window !== 'undefined') {
  (window as any).testDatabaseConnection = testDatabaseConnection;
}

export default testDatabaseConnection;