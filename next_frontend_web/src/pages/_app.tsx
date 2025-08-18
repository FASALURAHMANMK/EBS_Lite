import type { AppProps } from 'next/app';
import { AuthProvider } from '../context/AuthContext';
import { POSProvider } from '../context/MainContext';
import '../styles/globals.css';
import '../utils/dbTest';

function MyApp({ Component, pageProps }: AppProps) {
  return (
    <AuthProvider>
      <POSProvider>
        <Component {...pageProps} />
      </POSProvider>
    </AuthProvider>
  );
}

export default MyApp;
