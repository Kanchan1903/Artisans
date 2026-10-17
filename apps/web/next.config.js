/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  images: {
    domains: [
      "localhost",
      "images.unsplash.com",
      "minio",
    ],
    remotePatterns: [
      {
        protocol: "http",
        hostname: "**",
      },
      {
        protocol: "https",
        hostname: "**",
      },
    ],
  },
};

module.exports = nextConfig;
