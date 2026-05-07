import type { Config } from "tailwindcss";
const config: Config = {
  content: ["./app/**/*.{js,ts,jsx,tsx,mdx}", "./components/**/*.{js,ts,jsx,tsx,mdx}"],
  theme: {
    extend: {
      colors: {
        ink: "oklch(0.07 0.008 280)",
        "ink-2": "oklch(0.10 0.010 280)",
        surface: "oklch(0.13 0.012 280)",
        bone: "oklch(0.92 0.022 85)",
        "bone-2": "oklch(0.78 0.020 85)",
        "bone-muted": "oklch(0.62 0.014 85)",
        "bone-dim": "oklch(0.42 0.010 85)",
        accent: "oklch(0.85 0.140 165)",
        "accent-dim": "oklch(0.72 0.120 165)",
        warn: "oklch(0.78 0.130 75)",
      },
      fontFamily: {
        serif: ['"Times New Roman"', '"Noto Serif"', "Georgia", "serif"],
        sans: ["Inter", "-apple-system", "BlinkMacSystemFont", "system-ui", "sans-serif"],
        mono: ['"JetBrains Mono"', '"Fira Code"', "ui-monospace", "monospace"],
      },
    },
  },
  plugins: [],
};
export default config;
