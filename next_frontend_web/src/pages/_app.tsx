import type { AppProps } from 'next/app';
import { AuthProvider } from '../context/AuthContext';
import { MainProvider } from '../context/MainContext';
import { appWithTranslation } from 'next-i18next';
import '../styles/globals.css';

function MyApp({ Component, pageProps }: AppProps) {
  return (
    <AuthProvider>
      <MainProvider>
        <Component {...pageProps} />
      </MainProvider>
    </AuthProvider>
  );
}
export default appWithTranslation(MyApp);
