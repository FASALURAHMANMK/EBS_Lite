import PouchDB from 'pouchdb';
import PouchDBFind from 'pouchdb-find';

// Enable the find plugin
PouchDB.plugin(PouchDBFind);

export interface DatabaseConfig {
  localDB: string;
  remoteDB: string;
  username?: string;
  password?: string;
}

interface SyncStats {
  attempts: number;
  lastError: any | null;
  lastSuccess: Date | null;
}

export class DatabaseService {
  private static instance: DatabaseService;
  private databases: Map<string, PouchDB.Database> = new Map();
  private config: DatabaseConfig;
  private isOnline: boolean = false;
  private isInitialized: boolean = false;
  private syncHandlers: Map<string, any> = new Map();
  private syncStats: Map<string, SyncStats> = new Map();
  private reconnectTimeouts: Map<string, NodeJS.Timeout> = new Map();
  private maxReconnectAttempts: number = 5;
  private initializationPromise: Promise<void> | null = null;

  private constructor(config: DatabaseConfig) {
    this.config = config;
  }

  public static getInstance(config?: DatabaseConfig): DatabaseService {
    if (!DatabaseService.instance) {
      if (!config) {
        config = {
          localDB: 'pos_local',
          remoteDB: 'http://127.0.0.1:5984',
          username: 'admin',
          password: 'admin'
        };
      }
      DatabaseService.instance = new DatabaseService(config);
    }
    return DatabaseService.instance;
  }

  public async initialize(): Promise<void> {
    // Prevent multiple simultaneous initializations
    if (this.initializationPromise) {
      return this.initializationPromise;
    }

    if (this.isInitialized) {
      return Promise.resolve();
    }

    this.initializationPromise = this.performInitialization();
    return this.initializationPromise;
  }

  private async performInitialization(): Promise<void> {
    try {
      console.log('🚀 Starting database initialization...');
      
      // Setup online detection first
      this.setupOnlineDetection();
      
      // Initialize local databases (this should always work)
      await this.initializeLocalDatabases();
      console.log('💾 Local databases initialized');
      
      // Mark as initialized so app can work offline
      this.isInitialized = true;
      
      // Setup remote connections (can fail without breaking the app)
      await this.setupRemoteDatabases();
      
      // Setup sync for all databases
      await this.setupAllSync();
      
      // Test initial connectivity
      await this.testRemoteConnectivity();
      
      this.emitSyncEvent('initialized', 'system', { initialized: true });
      console.log('✅ Database initialization complete');
      
    } catch (error) {
      console.error('💥 Database initialization failed:', error);
      this.isInitialized = false;
      this.isOnline = false;
      throw error;
    } finally {
      this.initializationPromise = null;
    }
  }

  private async initializeLocalDatabases(): Promise<void> {
    const dbNames = [
      'users', 'locations', 'companies', 'products', 
      'categories', 'customers', 'sales', 'suppliers', 
      'credit_transactions'
    ];

    for (const dbName of dbNames) {
      try {
        const localDB = new PouchDB(`${this.config.localDB}_${dbName}`, {
          auto_compaction: true,
        });
        
        this.databases.set(dbName, localDB);
        await this.createIndexes(localDB, dbName);
        console.log(`✅ Local database ${dbName} ready`);
        
      } catch (error) {
        console.error(`❌ Failed to initialize local database ${dbName}:`, error);
        throw error;
      }
    }
  }

  private async setupRemoteDatabases(): Promise<void> {
    if (!this.config.remoteDB) {
      console.log('No remote database configured, running in local-only mode');
      this.isOnline = false;
      return;
    }

    console.log(`🔌 Setting up remote databases at: ${this.config.remoteDB}`);

    const dbNames = [
      'users', 'locations', 'companies', 'products', 
      'categories', 'customers', 'sales', 'suppliers', 
      'credit_transactions'
    ];

    const results = await Promise.allSettled(
      dbNames.map(dbName => this.setupRemoteDatabase(dbName))
    );

    const failures = results.filter(result => result.status === 'rejected');
    if (failures.length > 0) {
      console.warn(`⚠️ Some remote databases failed to setup: ${failures.length}/${dbNames.length}`);
      this.isOnline = false;
    } else {
      console.log('✅ All remote databases setup successfully');
      this.isOnline = true;
    }
  }

  private async setupRemoteDatabase(dbName: string): Promise<void> {
    try {
      const remoteUrl = `${this.config.remoteDB}/${dbName}`;
      
      const authHeader = this.config.username && this.config.password
        ? `Basic ${btoa(`${this.config.username}:${this.config.password}`)}`
        : '';

      // Check if database exists
      const checkResponse = await fetch(remoteUrl, {
        method: 'HEAD',
        headers: authHeader ? { 'Authorization': authHeader } : {},
        signal: AbortSignal.timeout(5000)
      });

      // Create database if it doesn't exist
      if (checkResponse.status === 404) {
        const createResponse = await fetch(remoteUrl, {
          method: 'PUT',
          headers: {
            'Authorization': authHeader,
            'Content-Type': 'application/json'
          },
          signal: AbortSignal.timeout(5000)
        });
        
        if (!createResponse.ok && createResponse.status !== 412) {
          throw new Error(`Failed to create remote database: ${createResponse.statusText}`);
        }
        console.log(`Created remote database: ${dbName}`);
      }

      // Setup remote connection
      const remoteDB = new PouchDB(remoteUrl, {
        auth: this.config.username && this.config.password ? {
          username: this.config.username,
          password: this.config.password
        } : undefined,
        skip_setup: true,
        adapter: 'http'
      });

      // Test connection
      await remoteDB.info();
      this.databases.set(`${dbName}_remote`, remoteDB);
      
    } catch (error: any) {
      console.warn(`❌ Remote setup failed for ${dbName}:`, error.message);
      throw error; // Re-throw to be caught by Promise.allSettled
    }
  }

  private async setupAllSync(): Promise<void> {
    const dbNames = [
      'users', 'locations', 'companies', 'products', 
      'categories', 'customers', 'sales', 'suppliers', 
      'credit_transactions'
    ];

    for (const dbName of dbNames) {
      const localDB = this.databases.get(dbName);
      const remoteDB = this.databases.get(`${dbName}_remote`);
      
      if (localDB && remoteDB) {
        // First perform initial push of existing data
        await this.performInitialPush(localDB, remoteDB, dbName);
        // Then setup continuous sync
        this.setupSync(localDB, remoteDB, dbName);
      }
    }
  }

  private async performInitialPush(localDB: PouchDB.Database, remoteDB: PouchDB.Database, dbName: string): Promise<void> {
    try {
      console.log(`⬆️ Performing initial push for ${dbName}...`);
      
      // Check if local DB has any documents
      const allDocs = await localDB.allDocs({ limit: 1 });
      
      if (allDocs.total_rows > 0) {
        console.log(`📤 Pushing ${allDocs.total_rows} existing documents from ${dbName}...`);
        
        await localDB.replicate.to(remoteDB, {
          retry: false,
          timeout: 15000,
          batch_size: 100
        });
        
        console.log(`✅ Initial push completed for ${dbName}`);
      } else {
        console.log(`📝 No existing data to push for ${dbName}`);
      }
      
    } catch (error: any) {
      console.warn(`⚠️ Initial push failed for ${dbName}:`, error.message);
      // Don't throw - continue with sync setup
    }
  }

  private setupSync(localDB: PouchDB.Database, remoteDB: PouchDB.Database, dbName: string): void {
    try {
      // Cancel any existing sync
      this.stopSync(dbName);
      
      console.log(`🔄 Setting up sync for ${dbName}...`);
      
      const syncHandler = PouchDB.sync(localDB, remoteDB, {
        live: true,
        retry: true,
        continuous: true,
        timeout: false,
        heartbeat: 10000,
        batch_size: 50,
        back_off_function: (delay) => Math.min(delay * 1.5, 60000)
      });

      this.syncHandlers.set(dbName, syncHandler);

      syncHandler.on('change', (info) => {
        const direction = info.direction;
        const docsCount = info.change?.docs?.length || 0;
        
        console.log(`📱 Real-time ${direction} sync in ${dbName}: ${docsCount} docs`);
        this.isOnline = true;
        
        this.updateSyncStats(dbName, 'success');
        
        // Emit more specific events
        this.emitSyncEvent('realtime_change', dbName, {
          direction,
          docs: docsCount,
          timestamp: new Date().toISOString(),
          docIds: info.change?.docs?.map(doc => doc._id) || []
        });

        // Also emit the generic sync_change for compatibility
        this.emitSyncEvent('sync_change', dbName, {
          direction,
          docs: docsCount,
          timestamp: new Date().toISOString()
        });
      });

      syncHandler.on('error', (err) => {
        console.error(`❌ Sync error in ${dbName}:`, err.message);
        
        this.updateSyncStats(dbName, 'error', err);
        
        if (this.isConnectionError(err)) {
          this.isOnline = false;
          this.emitSyncEvent('connection_lost', dbName, { error: err.message });
          this.handleSyncError(localDB, remoteDB, dbName, err);
        } else {
          this.emitSyncEvent('sync_error', dbName, { error: err.message });
        }
      });

      syncHandler.on('active', () => {
        console.log(`🟢 ${dbName} sync active - pushing/pulling enabled`);
        this.isOnline = true;
        this.updateSyncStats(dbName, 'success');
        this.emitSyncEvent('sync_active', dbName, { 
          active: true,
          timestamp: new Date().toISOString()
        });
      });

      syncHandler.on('paused', (err) => {
        if (err) {
          console.warn(`⏸️ ${dbName} sync paused with error:`, err.message);
          this.emitSyncEvent('sync_paused', dbName, { error: err.message });
        } else {
          console.log(`⏸️ ${dbName} sync paused normally (up to date)`);
          this.emitSyncEvent('sync_paused', dbName, { reason: 'up_to_date' });
        }
      });

      syncHandler.on('complete', (info) => {
        console.log(`✅ ${dbName} sync completed`);
        this.updateSyncStats(dbName, 'complete');
        this.emitSyncEvent('sync_complete', dbName, { 
          info,
          timestamp: new Date().toISOString()
        });
      });

      // Force an initial sync check to trigger any pending changes
      setTimeout(() => {
        console.log(`🔍 Triggering initial sync check for ${dbName}`);
        // This will cause sync to check for any differences
        localDB.info().then(() => {
          // Just getting info can sometimes trigger pending syncs
        }).catch(() => {
          // Ignore errors here
        });
      }, 1000);

      console.log(`✅ Sync setup complete for ${dbName}`);

    } catch (error) {
      console.error(`Failed to setup sync for ${dbName}:`, error);
      this.isOnline = false;
    }
  }

  private isConnectionError(error: any): boolean {
    const message = error.message || '';
    return message.includes('ECONNREFUSED') || 
           message.includes('timeout') || 
           message.includes('fetch') || 
           message.includes('Network request failed') ||
           error.name === 'unauthorized';
  }

  private updateSyncStats(dbName: string, type: 'success' | 'error' | 'complete', error?: any): void {
    const stats = this.syncStats.get(dbName) || { 
      attempts: 0, 
      lastError: null, 
      lastSuccess: null 
    };
    
    if (type === 'error') {
      stats.attempts += 1;
      stats.lastError = { message: error?.message, timestamp: new Date() };
    } else if (type === 'success' || type === 'complete') {
      stats.attempts = 0;
      stats.lastSuccess = new Date();
      stats.lastError = null;
    }
    
    this.syncStats.set(dbName, stats);
  }

  private handleSyncError(localDB: PouchDB.Database, remoteDB: PouchDB.Database, dbName: string, error: any): void {
    const stats = this.syncStats.get(dbName);
    
    if (!stats || stats.attempts < this.maxReconnectAttempts) {
      const attempts = stats?.attempts || 0;
      const delay = Math.min(2000 * Math.pow(2, attempts), 60000);
      
      console.log(`Retrying sync for ${dbName} in ${delay}ms (attempt ${attempts + 1}/${this.maxReconnectAttempts})`);
      
      // Clear any existing timeout
      const existingTimeout = this.reconnectTimeouts.get(dbName);
      if (existingTimeout) {
        clearTimeout(existingTimeout);
      }
      
      const timeout = setTimeout(() => {
        this.setupSync(localDB, remoteDB, dbName);
      }, delay);
      
      this.reconnectTimeouts.set(dbName, timeout);
    } else {
      console.warn(`Max reconnection attempts reached for ${dbName}`);
      this.emitSyncEvent('max_retries_reached', dbName, { 
        error, 
        maxAttempts: this.maxReconnectAttempts 
      });
    }
  }

  private stopSync(dbName: string): void {
    const syncHandler = this.syncHandlers.get(dbName);
    if (syncHandler && typeof syncHandler.cancel === 'function') {
      syncHandler.cancel();
    }
    this.syncHandlers.delete(dbName);
    
    const timeout = this.reconnectTimeouts.get(dbName);
    if (timeout) {
      clearTimeout(timeout);
      this.reconnectTimeouts.delete(dbName);
    }
  }

  private async createIndexes(db: PouchDB.Database, dbName: string): Promise<void> {
    const indexes: Record<string, any[]> = {
      users: [
        { index: { fields: ['username'] }, name: 'idx_username' },
        { index: { fields: ['email'] }, name: 'idx_email' },
        { index: { fields: ['companyId'] }, name: 'idx_company_id' },
        { index: { fields: ['companyId', 'isActive'] }, name: 'idx_company_active' }
      ],
      products: [
        { index: { fields: ['sku'] }, name: 'idx_sku' },
        { index: { fields: ['category'] }, name: 'idx_category' },
        { index: { fields: ['companyId'] }, name: 'idx_company_id' },
        { index: { fields: ['locationId'] }, name: 'idx_location_id' },
        { index: { fields: ['name'] }, name: 'idx_name' },
        { index: { fields: ['companyId', 'isActive'] }, name: 'idx_company_active' },
        { index: { fields: ['companyId', 'locationId', 'isActive'] }, name: 'idx_company_location_active' }
      ],
      customers: [
        { index: { fields: ['phone'] }, name: 'idx_phone' },
        { index: { fields: ['email'] }, name: 'idx_email' },
        { index: { fields: ['companyId'] }, name: 'idx_company_id' },
        { index: { fields: ['locationId'] }, name: 'idx_location_id' },
        { index: { fields: ['name'] }, name: 'idx_name' },
        { index: { fields: ['companyId', 'locationId', 'isActive'] }, name: 'idx_company_location_active' }
      ],
      sales: [
        { index: { fields: ['customerId'] }, name: 'idx_customer_id' },
        { index: { fields: ['date'] }, name: 'idx_date' },
        { index: { fields: ['createdAt'] }, name: 'idx_created_at' },
        { index: { fields: ['companyId'] }, name: 'idx_company_id' },
        { index: { fields: ['locationId'] }, name: 'idx_location_id' },
        { index: { fields: ['userId'] }, name: 'idx_user_id' },
        { index: { fields: ['companyId', 'locationId'] }, name: 'idx_company_location' },
        { index: { fields: ['date'] }, name: 'idx_date_only' }
      ],
      categories: [
        { index: { fields: ['name'] }, name: 'idx_name' },
        { index: { fields: ['companyId'] }, name: 'idx_company_id' },
        { index: { fields: ['locationId'] }, name: 'idx_location_id' },
        { index: { fields: ['companyId', 'locationId', 'isActive'] }, name: 'idx_company_location_active' }
      ],
      suppliers: [
        { index: { fields: ['name'] }, name: 'idx_name' },
        { index: { fields: ['companyId'] }, name: 'idx_company_id' },
        { index: { fields: ['locationId'] }, name: 'idx_location_id' },
        { index: { fields: ['companyId', 'locationId', 'isActive'] }, name: 'idx_company_location_active' }
      ],
      companies: [
        { index: { fields: ['name'] }, name: 'idx_name' },
        { index: { fields: ['code'] }, name: 'idx_code' },
        { index: { fields: ['isActive'] }, name: 'idx_active' }
      ],
      locations: [
        { index: { fields: ['name'] }, name: 'idx_name' },
        { index: { fields: ['companyId'] }, name: 'idx_company_id' },
        { index: { fields: ['companyId', 'isActive'] }, name: 'idx_company_active' }
      ],
      credit_transactions: [
        { index: { fields: ['customerId'] }, name: 'idx_customer_id' },
        { index: { fields: ['date'] }, name: 'idx_date' },
        { index: { fields: ['companyId'] }, name: 'idx_company_id' },
        { index: { fields: ['locationId'] }, name: 'idx_location_id' },
        { index: { fields: ['customerId', 'date'] }, name: 'idx_customer_date' }
      ]
    };

    const dbIndexes = indexes[dbName] || [];
    
    for (const indexDef of dbIndexes) {
      try {
        const result = await db.createIndex(indexDef);
        if (result.result === 'created') {
          console.log(`✓ Created index in ${dbName}: ${indexDef.name}`);
        }
      } catch (err: any) {
        console.warn(`✗ Index creation failed for ${dbName}.${indexDef.name}:`, err.message);
      }
    }

    // Wait for indexes to be ready
    await new Promise(resolve => setTimeout(resolve, 100));
  }

  private setupOnlineDetection(): void {
    if (typeof window === 'undefined' || typeof navigator === 'undefined') {
      this.isOnline = false;
      return;
    }

    // Test connectivity immediately
    this.testRemoteConnectivity();
    
    // Test connectivity every 30 seconds
    setInterval(() => {
      this.testRemoteConnectivity();
    }, 30000);

    window.addEventListener('online', () => {
      console.log('🌐 Browser reports online');
      setTimeout(() => {
        this.testRemoteConnectivity();
        this.resumeAllSync();
      }, 1000);
    });

    window.addEventListener('offline', () => {
      console.log('📵 Browser reports offline');
      this.isOnline = false;
      this.emitSyncEvent('offline', 'system', { online: false });
      this.pauseAllSync();
    });
  }

  private async testRemoteConnectivity(): Promise<void> {
    if (!this.config.remoteDB) {
      this.isOnline = false;
      return;
    }

    try {
      const authHeader = this.config.username && this.config.password
        ? `Basic ${btoa(`${this.config.username}:${this.config.password}`)}`
        : '';

      const response = await fetch(this.config.remoteDB, {
        method: 'HEAD',
        headers: authHeader ? { 'Authorization': authHeader } : {},
        signal: AbortSignal.timeout(5000)
      });

      const wasOnline = this.isOnline;
      this.isOnline = response.ok;

      if (this.isOnline && !wasOnline) {
        console.log('✅ Remote connectivity established');
        this.emitSyncEvent('online', 'system', { online: true, status: response.status });
      } else if (!this.isOnline && wasOnline) {
        console.log('❌ Remote connectivity lost');
        this.emitSyncEvent('offline', 'system', { online: false, status: response.status });
      }

    } catch (error: any) {
      const wasOnline = this.isOnline;
      this.isOnline = false;
      
      if (wasOnline) {
        console.warn('❌ Remote connectivity test failed:', error.message);
        this.emitSyncEvent('offline', 'system', { online: false, error: error.message });
      }
    }
  }

  private resumeAllSync(): void {
    this.syncHandlers.forEach((handler, dbName) => {
      if (handler && typeof handler.resume === 'function') {
        try {
          handler.resume();
          console.log(`▶️ Resumed sync for ${dbName}`);
        } catch (error) {
          console.error(`Failed to resume sync for ${dbName}:`, error);
        }
      }
    });
  }

  private pauseAllSync(): void {
    this.syncHandlers.forEach((handler, dbName) => {
      if (handler && typeof handler.pause === 'function') {
        try {
          handler.pause();
          console.log(`⏸️ Paused sync for ${dbName}`);
        } catch (error) {
          console.error(`Failed to pause sync for ${dbName}:`, error);
        }
      }
    });
  }

  private emitSyncEvent(type: string, dbName: string, data: any): void {
    if (typeof window !== 'undefined') {
      const event = new CustomEvent('db-sync', {
        detail: { type, dbName, data, timestamp: new Date() }
      });
      window.dispatchEvent(event);
    }
  }

  // Public API methods

  public getDatabase(name: string): PouchDB.Database {
    const db = this.databases.get(name);
    if (!db) {
      throw new Error(`Database ${name} not found. Make sure initialize() was called.`);
    }
    return db;
  }

  public isOnlineStatus(): boolean {
    return this.isOnline;
  }

  public isInitializedStatus(): boolean {
    return this.isInitialized;
  }

  public async forceSync(dbName: string, operation: 'push' | 'pull' | 'both' = 'both'): Promise<void> {
    const localDB = this.databases.get(dbName);
    const remoteDB = this.databases.get(`${dbName}_remote`);
    
    if (!localDB) {
      console.warn(`Local database ${dbName} not found`);
      return;
    }
    
    if (!remoteDB) {
      console.warn(`Remote database ${dbName} not found - skipping sync`);
      return;
    }

    try {
      console.log(`🔄 Force syncing ${dbName} (${operation})...`);
      
      const options = {
        retry: false,
        timeout: 10000,
        batch_size: 50
      };

      if (operation === 'pull' || operation === 'both') {
        await localDB.replicate.from(remoteDB, options);
      }
      
      if (operation === 'push' || operation === 'both') {
        await localDB.replicate.to(remoteDB, options);
      }
      
      console.log(`✅ Force sync completed for ${dbName} (${operation})`);
      this.isOnline = true;
      this.emitSyncEvent('sync_success', dbName, { operation });
      
    } catch (error: any) {
      console.warn(`❌ Force sync failed for ${dbName}:`, error.message);
      if (this.isConnectionError(error)) {
        this.isOnline = false;
      }
      throw error;
    }
  }

  public retrySyncForDatabase(dbName: string): void {
    const localDB = this.databases.get(dbName);
    const remoteDB = this.databases.get(`${dbName}_remote`);
    
    if (localDB && remoteDB) {
      console.log(`Manually retrying sync for ${dbName}`);
      this.setupSync(localDB, remoteDB, dbName);
    }
  }

  // Add method to push all pending changes
  public async pushAllPendingChanges(): Promise<void> {
    const dbNames = [
      'users', 'locations', 'companies', 'products', 
      'categories', 'customers', 'sales', 'suppliers', 
      'credit_transactions'
    ];

    console.log('🚀 Pushing all pending changes...');
    
    const pushPromises = dbNames.map(async (dbName) => {
      try {
        await this.forceSync(dbName, 'push');
        console.log(`✅ Pushed pending changes for ${dbName}`);
      } catch (error: any) {
        console.warn(`❌ Failed to push ${dbName}:`, error.message);
      }
    });

    await Promise.allSettled(pushPromises);
    console.log('🏁 Push all pending changes completed');
  }

  // Add method to check sync status for debugging
  public getSyncStatus(): Record<string, any> {
    const status: Record<string, any> = {};
    
    this.syncHandlers.forEach((handler, dbName) => {
      const stats = this.syncStats.get(dbName);
      status[dbName] = {
        hasHandler: !!handler,
        hasLocalDB: !!this.databases.get(dbName),
        hasRemoteDB: !!this.databases.get(`${dbName}_remote`),
        stats: stats || null
      };
    });
    
    return {
      isOnline: this.isOnline,
      isInitialized: this.isInitialized,
      databases: status
    };
  }

  // Generic CRUD operations

  public async create(dbName: string, doc: any): Promise<any> {
    const db = this.getDatabase(dbName);
    doc._id = doc._id || `${dbName}_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    doc.createdAt = doc.createdAt || new Date().toISOString();
    doc.updatedAt = new Date().toISOString();
    
    const result = await db.post(doc);
    const createdDoc = { ...doc, _id: result.id, _rev: result.rev };
    
    // Immediate push to remote for real-time sync
    if (this.isOnline) {
      setTimeout(() => {
        this.forceSync(dbName, 'push').then(() => {
          console.log(`📤 Real-time push completed for ${dbName}: ${result.id}`);
          this.emitSyncEvent('realtime_push', dbName, { 
            docId: result.id, 
            operation: 'create' 
          });
        }).catch(err => {
          console.debug(`⚠️ Real-time push failed for ${dbName}:`, err.message);
        });
      }, 50); // Small delay to ensure document is fully committed
    }
    
    return createdDoc;
  }

  public async update(dbName: string, doc: any): Promise<any> {
    const db = this.getDatabase(dbName);
    doc.updatedAt = new Date().toISOString();
    
    const result = await db.put(doc);
    const updatedDoc = { ...doc, _rev: result.rev };
    
    // Immediate push to remote for real-time sync
    if (this.isOnline) {
      setTimeout(() => {
        this.forceSync(dbName, 'push').then(() => {
          console.log(`📤 Real-time update push completed for ${dbName}: ${doc._id}`);
          this.emitSyncEvent('realtime_push', dbName, { 
            docId: doc._id, 
            operation: 'update' 
          });
        }).catch(err => {
          console.debug(`⚠️ Real-time update push failed for ${dbName}:`, err.message);
        });
      }, 50);
    }
    
    return updatedDoc;
  }

  public async delete(dbName: string, docId: string): Promise<boolean> {
    const db = this.getDatabase(dbName);
    const doc = await db.get(docId);
    await db.remove(doc);
    return true;
  }

  public async findById(dbName: string, id: string): Promise<any> {
    const db = this.getDatabase(dbName);
    try {
      return await db.get(id);
    } catch (err: any) {
      if (err.status === 404) {
        return null;
      }
      throw err;
    }
  }

  public async find(dbName: string, query: any): Promise<any[]> {
    const db = this.getDatabase(dbName);

    try {
      // Ensure indexes exist for sort fields with more robust creation
      if (query.sort && Array.isArray(query.sort)) {
        for (const sortField of query.sort) {
          const fieldName = typeof sortField === 'string' ? sortField : Object.keys(sortField)[0];
          
          try {
            // For sales and createdAt specifically, ensure proper index
            if (dbName === 'sales' && fieldName === 'createdAt') {
              await db.createIndex({ 
                index: { fields: ['createdAt'] },
                name: 'idx_created_at_sort'
              });
            } else {
              await db.createIndex({ index: { fields: [fieldName] } });
            }
          } catch (indexError) {
            console.warn(`Index creation failed for ${fieldName}:`, indexError);
          }
        }
        
        // Wait longer for index to be ready
        await new Promise(resolve => setTimeout(resolve, 200));
      }

      const result = await db.find(query);
      return result.docs;
      
    } catch (error: any) {
      if (error.message && (error.message.includes('Cannot sort on field') || error.message.includes('no matching index'))) {
        console.warn(`Sort query failed for ${dbName}, retrying without sort:`, error.message);
        
        const fallbackQuery = { ...query };
        delete fallbackQuery.sort;
        
        try {
          const result = await db.find(fallbackQuery);
          
          // Sort in memory if needed - improved sorting logic
          if (query.sort && result.docs.length > 0) {
            const sortField = Array.isArray(query.sort) ? query.sort[0] : query.sort;
            const fieldName = typeof sortField === 'string' ? sortField : Object.keys(sortField)[0];
            const sortOrder = typeof sortField === 'string' ? 'asc' : Object.values(sortField)[0];
            
            result.docs.sort((a, b) => {
              let aVal = a[fieldName];
              let bVal = b[fieldName];
              
              // Handle date strings properly
              if (fieldName === 'createdAt' || fieldName === 'date') {
                aVal = new Date(aVal).getTime();
                bVal = new Date(bVal).getTime();
              }
              
              // Handle null/undefined values
              if (aVal == null && bVal == null) return 0;
              if (aVal == null) return 1;
              if (bVal == null) return -1;
              
              if (sortOrder === 'desc') {
                return bVal > aVal ? 1 : bVal < aVal ? -1 : 0;
              }
              return aVal > bVal ? 1 : aVal < bVal ? -1 : 0;
            });
          }
          
          return result.docs;
        } catch (fallbackError) {
          console.error(`Fallback query also failed for ${dbName}:`, fallbackError);
          throw fallbackError;
        }
      }
      
      console.error(`Database query failed for ${dbName}:`, error);
      throw error;
    }
  }

  public async findAll(dbName: string, companyId?: string): Promise<any[]> {
    const query: any = {
      selector: {},
      limit: 1000
    };

    if (companyId) {
      query.selector.companyId = companyId;
    }

    return this.find(dbName, query);
  }

  // Authentication methods

  public async authenticateUser(username: string, password: string): Promise<any> {
    const users = await this.find('users', {
      selector: {
        $or: [
          { username: username },
          { email: username }
        ]
      }
    });

    const user = users[0];
    if (!user) {
      throw new Error('User not found');
    }

    const hashedPassword = await this.hashPassword(password);
    if (user.password !== hashedPassword) {
      throw new Error('Invalid password');
    }

    const { password: _, ...userWithoutPassword } = user;
    return userWithoutPassword;
  }

  public async createUser(userData: any): Promise<any> {
    console.log('👤 Creating user...');
    
    try {
      if (!this.isInitialized) {
        throw new Error('Database not initialized for user creation');
      }
      
      // Check for existing users
      let existingUsers = [];
      try {
        existingUsers = await this.find('users', {
          selector: {
            $or: [
              { username: userData.username },
              { email: userData.email }
            ]
          }
        });
      } catch (error) {
        console.warn('Could not check existing users, proceeding:', error);
      }

      if (existingUsers.length > 0) {
        throw new Error('User with this username or email already exists');
      }

      const hashedPassword = await this.hashPassword(userData.password);
      
      const newUserData = {
        ...userData,
        password: hashedPassword,
        role: userData.role || 'admin',
        isActive: true,
        permissions: userData.permissions || ['all'],
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString()
      };

      console.log('💾 Saving user to local database...');
      const user = await this.create('users', newUserData);

      // Background sync
      setTimeout(() => {
        if (this.isOnline) {
          this.forceSync('users', 'push').then(() => {
            console.log('✅ User synced to remote');
          }).catch(err => {
            console.warn('⚠️ User sync failed (data is safe locally):', err);
          });
        } else {
          console.log('📱 Offline mode - user saved locally, will sync when online');
        }
      }, 100);

      console.log('✅ User created successfully:', user._id);
      return user;
      
    } catch (error: any) {
      console.error('❌ User creation failed:', error);
      throw new Error(`Failed to create user: ${error.message}`);
    }
  }

  private async hashPassword(password: string): Promise<string> {
    const salt = 'pos_salt_2025';
    const textToHash = password + salt;
    
    if (typeof crypto !== 'undefined' && crypto.subtle) {
      try {
        const encoder = new TextEncoder();
        const data = encoder.encode(textToHash);
        const hashBuffer = await crypto.subtle.digest('SHA-256', data);
        const hashArray = Array.from(new Uint8Array(hashBuffer));
        return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
      } catch (error) {
        console.warn('WebCrypto failed, falling back to simple hash');
        return this.simpleHash(textToHash);
      }
    } else {
      return this.simpleHash(textToHash);
    }
  }

  private simpleHash(text: string): string {
    let hash = 0;
    if (text.length === 0) return hash.toString();
    
    for (let i = 0; i < text.length; i++) {
      const char = text.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash;
    }
    
    const positiveHash = Math.abs(hash).toString(16);
    return `hash_${positiveHash}_${text.length}`;
  }

  // Company and Location methods

  public async createCompany(companyData: any): Promise<any> {
    console.log('🏢 Creating company...');
    
    try {
      if (!this.isInitialized) {
        console.log('⏳ Database not ready, waiting...');
        await new Promise(resolve => setTimeout(resolve, 1000));
        
        if (!this.isInitialized) {
          throw new Error('Database not initialized for company creation');
        }
      }
      
      let companyCount = 0;
      try {
        const companies = await this.findAll('companies');
        companyCount = companies.length;
      } catch (error) {
        console.warn('Could not get existing companies count, using 0:', error);
      }
      
      const companyCode = `COMP${(companyCount + 1).toString().padStart(4, '0')}`;
      
      const newCompanyData = {
        ...companyData,
        code: companyCode,
        isActive: true,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString()
      };
      
      console.log('💾 Saving company to local database...');
      const company = await this.create('companies', newCompanyData);
      
      console.log('🏪 Creating default location...');
      const defaultLocation = await this.createLocation({
        name: 'Default',
        code: 'LOC001',
        address: companyData.address,
        phone: companyData.phone,
        email: companyData.email,
        companyId: company._id,
        isMainLocation: true,
        isActive: true
      });
      
      company.locations = [defaultLocation];
      
      // Background sync
      setTimeout(() => {
        if (this.isOnline) {
          Promise.all([
            this.forceSync('companies', 'push'),
            this.forceSync('locations', 'push')
          ]).then(() => {
            console.log('✅ Company and location synced to remote');
          }).catch(err => {
            console.warn('⚠️ Background sync failed (data is safe locally):', err);
          });
        } else {
          console.log('📱 Offline mode - company saved locally, will sync when online');
        }
      }, 100);
      
      console.log('✅ Company created successfully:', company._id);
      return company;
      
    } catch (error: any) {
      console.error('❌ Company creation failed:', error);
      throw new Error(`Failed to create company: ${error.message}`);
    }
  }

  public async getCompanyData(companyId: string): Promise<any> {
    const company = await this.findById('companies', companyId);
    if (company) {
      const locations = await this.getCompanyLocations(companyId);
      company.locations = locations;
    }
    return company;
  }

  public async createLocation(locationData: any): Promise<any> {
    if (!locationData.companyId) throw new Error('Company ID required');
    
    console.log('📍 Creating location...');
    
    const existingLocations = await this.find('locations', {
      selector: { companyId: locationData.companyId }
    });
    
    const locationCode = `LOC${(existingLocations.length + 1).toString().padStart(3, '0')}`;
    
    const location = await this.create('locations', {
      ...locationData,
      code: locationCode,
      isActive: true
    });
    
    console.log('✅ Location created:', location._id);
    return location;
  }

  public async getCompanyLocations(companyId: string): Promise<any[]> {
    return await this.find('locations', {
      selector: { 
        companyId: companyId,
        isActive: true 
      }
    });
  }

  // Customer and Credit methods

  public async updateCustomerCredit(
    customerId: string, 
    amount: number, 
    type: 'credit' | 'debit', 
    description: string, 
    locationId?: string
  ): Promise<any> {
    const customer = await this.findById('customers', customerId);
    if (!customer) {
      throw new Error('Customer not found');
    }

    const currentBalance = customer.creditBalance || 0;
    const newBalance = type === 'credit' ? currentBalance - amount : currentBalance + amount;

    customer.creditBalance = newBalance;
    await this.update('customers', customer);

    const transaction = {
      customerId,
      amount,
      type,
      description,
      previousBalance: currentBalance,
      newBalance,
      date: new Date().toISOString(),
      companyId: customer.companyId,
      locationId: locationId || customer.locationId
    };

    await this.create('credit_transactions', transaction);

    return { customer, transaction };
  }

  public async getCustomerCreditHistory(customerId: string): Promise<any[]> {
    return await this.find('credit_transactions', {
      selector: { customerId },
      sort: [{ date: 'desc' }]
    });
  }

  public async getCustomerCreditBalance(customerId: string): Promise<number> {
    const customer = await this.findById('customers', customerId);
    return customer ? (customer.creditBalance || 0) : 0;
  }

  // Sales methods

  public async createSale(saleData: any): Promise<any> {
    const today = new Date();
    const dateStr = today.toISOString().slice(0, 10).replace(/-/g, '');
    
    // Generate location-specific sale number
    const todaySales = await this.find('sales', {
      selector: {
        date: {
          $gte: `${dateStr}T00:00:00.000Z`,
          $lt: `${dateStr}T23:59:59.999Z`
        },
        companyId: saleData.companyId,
        locationId: saleData.locationId
      }
    });

    const saleNumber = `SAL-${dateStr}-${saleData.locationId?.slice(-3) || 'LOC'}-${(todaySales.length + 1).toString().padStart(4, '0')}`;
    
    saleData.saleNumber = saleNumber;
    saleData.date = new Date().toISOString();
    
    // Update product stock
    for (const item of saleData.items) {
      const product = await this.findById('products', item.productId);
      if (product && product.locationId === saleData.locationId) {
        product.stock -= item.quantity;
        await this.update('products', product);
      }
    }

    // Handle customer credit if payment method is credit
    if (saleData.paymentMethod === 'credit' && saleData.customerId) {
      await this.updateCustomerCredit(
        saleData.customerId,
        saleData.total,
        'debit',
        `Sale ${saleNumber}`,
        saleData.locationId
      );
    }

    return await this.create('sales', saleData);
  }
}