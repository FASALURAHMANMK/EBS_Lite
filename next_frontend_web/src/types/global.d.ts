declare global {
  interface Window {
    ENV: {
      NEXT_PUBLIC_COUCHDB_URL?: string;
      NODE_ENV?: string;
    };
    testDatabaseConnection?: () => Promise<any>;
    runDatabaseTests?: () => Promise<any>;
    initializeDatabaseWithSampleData?: () => Promise<any>;
    DatabaseTester?: any;
    setEnvOverride?: (key: string, value: string) => void;
  }
}

export {};