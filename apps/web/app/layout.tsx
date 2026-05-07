import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "He Was Socrates · A bust that refuses to answer",
  description: "100% on-device Korean Socratic bust on macOS, powered by Gemma 4 E4B 4-bit MLX. The abstention mechanic is the product.",
  openGraph: {
    title: "He Was Socrates · A bust that refuses to answer",
    description: "A bust that refuses to answer is the product. 100% on-device, Korean 단정한 평어체, Gemma 4 native function calling.",
    type: "website",
  },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className="bg-ink text-bone font-sans antialiased">{children}</body>
    </html>
  );
}
