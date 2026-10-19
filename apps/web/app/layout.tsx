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
      <head>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous" />
        <link
          href="https://fonts.googleapis.com/css2?family=Noto+Sans:ital,wght@0,300;0,400;0,500;0,600;0,700;0,800;1,400&family=Noto+Serif+Devanagari:wght@400;600;700;800&family=Noto+Serif:ital,wght@0,400;0,700;1,400&display=swap"
          rel="stylesheet"
        />
      </head>
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
