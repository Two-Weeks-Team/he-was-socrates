/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'export',
  images: { unoptimized: true },
  reactStrictMode: true,
  // No analytics, no telemetry
  experimental: {
    optimizePackageImports: [],
    // Inline CSS into <style> in <head> to eliminate render-blocking
    // external stylesheet round-trip. Critical for LCP on the single-page
    // gh-pages surface. https://nextjs.org/docs/app/api-reference/config/next-config-js/inlineCss
    inlineCss: true,
  },
};
export default nextConfig;
