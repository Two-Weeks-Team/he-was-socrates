/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'export',
  images: { unoptimized: true },
  reactStrictMode: true,
  // No analytics, no telemetry
  experimental: {
    optimizePackageImports: [],
  },
};
export default nextConfig;
