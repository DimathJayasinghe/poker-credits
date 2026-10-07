import type { NextConfig } from 'next'

const nextConfig: NextConfig = {
  // Allow importing from @poker-credits/shared workspace package
  transpilePackages: ['@poker-credits/shared'],
}

export default nextConfig
