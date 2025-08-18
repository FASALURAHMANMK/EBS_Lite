import { Html, Head, Main, NextScript } from 'next/document'

export default function Document() {
  return (
    <Html lang="en">
      <Head>
        <meta charSet="utf-8" />
        <meta name="description" content="Einfach Business Suite - Complete POS Solution" />
        <meta name="keywords" content="POS, Point of Sale, Business Management, Inventory" />
        <meta name="author" content="Einfach Digital Solutions" />
        <link rel="icon" href="/favicon.ico" />
        
        {/* Load environment variables for Electron */}
        <script src="/env.js"></script>
      </Head>
      <body>
        <Main />
        <NextScript />
      </body>
    </Html>
  )
}