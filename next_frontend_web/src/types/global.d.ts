declare global {
  interface Window {
    ENV: {
      NEXT_PUBLIC_API_URL?: string;
      NODE_ENV?: string;
    };
    setEnvOverride?: (key: string, value: string) => void;
  }
}

export {};
