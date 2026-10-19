import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
    "./lib/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        terracotta: {
          DEFAULT: "#C85A32",
          dark: "#9E3A19",
          light: "#FBECE6",
        },
        indigo: {
          DEFAULT: "#2C3E6B",
          dark: "#1B2745",
          light: "#E9EDF5",
        },
        turmeric: {
          DEFAULT: "#E09F3E",
          dark: "#C78322",
          light: "#FCF5E8",
        },
        sand: {
          DEFAULT: "#FAF7F2",
          warm: "#F3EFE6",
        },
        charcoal: "#262220",
      },
      fontFamily: {
        sans: ["var(--font-noto-sans)", "system-ui", "sans-serif"],
        serif: ["var(--font-noto-serif)", "serif"],
      },
    },
  },
  plugins: [],
};

export default config;
