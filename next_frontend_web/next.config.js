const { i18n } = require('./next-i18next.config');

/** @type {import('next').NextConfig} */
const nextConfig = {
  i18n,
  images: {
    unoptimized: true,
  },
  distDir: 'out',
  async rewrites() {
    const apiProxyUrl = process.env.API_PROXY_URL || process.env.NEXT_PUBLIC_API_URL;
    if (!apiProxyUrl) {
      return [];
    }
    return [
      {
        source: '/api/:path*',
        destination: `${apiProxyUrl}/api/:path*`,
      },
    ];
  },
};

module.exports = nextConfig;
