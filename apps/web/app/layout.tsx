import type { Metadata } from "next";
import "./globals.css";
import { CartProvider } from "@/lib/cart-context";
import { AuthProvider } from "@/lib/auth-context";
import { LanguageProvider } from "@/lib/language-context";
import ShellWrapper from "@/components/ShellWrapper";

export const metadata: Metadata = {
  title: "KalaSathi | Direct Handcrafted Treasures from Indian Artisans",
  description:
    "AI-powered ethical e-commerce connecting marginalized Indian artisans directly to global buyers. Handcrafted pottery, Warli folk paintings, Channapatna wooden toys, and handlooms.",
  keywords: [
    "Indian handicrafts",
    "artisan marketplace",
    "Warli art",
    "Madhubani painting",
    "Channapatna toys",
    "terracotta pottery",
    "fair trade India",
  ],
  openGraph: {
    title: "KalaSathi | AI-Powered Artisan Marketplace",
    description: "Authentic handmade Indian crafts direct from village creators with fair wage guarantee.",
    type: "website",
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className="min-h-screen flex flex-col bg-[#FAF7F2] text-[#262220]">
        <LanguageProvider>
          <AuthProvider>
            <CartProvider>
              <ShellWrapper>{children}</ShellWrapper>
            </CartProvider>
          </AuthProvider>
        </LanguageProvider>
      </body>
    </html>
  );
}
