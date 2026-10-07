import type { Config } from 'tailwindcss'

const config: Config = {
  content: [
    './app/**/*.{ts,tsx}',
    './components/**/*.{ts,tsx}',
    './src/**/*.{ts,tsx}',
  ],
  theme: {
    extend: {
      colors: {
        // Poker felt design tokens
        felt: {
          DEFAULT: '#0a4f2e',
          dark: '#062e1a',
          light: '#0d6b3e',
        },
        chip: {
          gold: '#eab308',
          silver: '#94a3b8',
          red: '#dc2626',
          blue: '#2563eb',
          black: '#1e1e1e',
        },
      },
    },
  },
  plugins: [],
}

export default config
