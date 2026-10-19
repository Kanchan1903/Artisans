"use client";

import Link from "next/link";
import { Smartphone, ArrowRight, ShoppingBag } from "lucide-react";

/**
 * Artisan dashboard is MOBILE ONLY.
 * Web artisan dashboard route redirects to this informational page.
 */
export default function ArtisanWebPage() {
  return (
    <div className="min-h-screen bg-gradient-to-br from-[#FAF7F2] via-[#F5EFE5] to-[#EDE3D5] flex items-center justify-center px-4 py-16">
      {/* Decorative blobs */}
      <div className="fixed top-0 right-0 w-96 h-96 bg-[#2C3E6B]/5 rounded-full -translate-y-1/2 translate-x-1/2 pointer-events-none" />
      <div className="fixed bottom-0 left-0 w-80 h-80 bg-[#C85A32]/5 rounded-full translate-y-1/2 -translate-x-1/2 pointer-events-none" />

      <div className="relative max-w-lg w-full text-center">
        {/* Artisan icon */}
        <div className="w-24 h-24 rounded-3xl bg-[#2C3E6B] flex items-center justify-center mx-auto mb-6 shadow-xl shadow-[#2C3E6B]/25">
          <span className="text-5xl">🎨</span>
        </div>

        <span className="inline-block px-3 py-1 bg-[#2C3E6B]/10 text-[#2C3E6B] text-xs font-bold uppercase tracking-wider rounded-full mb-4">
          For Artisans
        </span>

        <h1 className="font-serif text-4xl font-black text-stone-900 mb-4 leading-tight">
          The Artisan Dashboard<br />lives in the <span className="text-[#C85A32]">Mobile App</span>
        </h1>

        <p className="text-stone-600 text-base leading-relaxed mb-8 max-w-md mx-auto">
          KalaSathi is designed for artisans to use on their <strong>phone</strong> — record your product in your language, 
          photograph it, get a fair price, and publish it — all without typing a single word.
        </p>

        {/* Feature pills */}
        <div className="flex flex-wrap justify-center gap-2 mb-10">
          {["🎤 Voice in 12 Languages", "📸 AI Image Studio", "💰 Fair Pricing", "📦 Order Notifications", "🌐 Offline Mode"].map((f) => (
            <span key={f} className="px-3 py-1.5 bg-white border border-stone-200 rounded-full text-xs font-semibold text-stone-700 shadow-sm">
              {f}
            </span>
          ))}
        </div>

        {/* Download CTA */}
        <div className="bg-white rounded-3xl p-8 border border-stone-200 shadow-lg mb-6">
          <Smartphone className="w-10 h-10 text-[#2C3E6B] mx-auto mb-4" />
          <h2 className="font-serif text-xl font-bold text-stone-900 mb-2">Download the KalaSathi App</h2>
          <p className="text-sm text-stone-500 mb-6">
            Available for Android. Speak in Hindi, Marathi, Tamil, Telugu, Bengali, or any of 12 Indian languages.
          </p>
          <div className="flex flex-col sm:flex-row gap-3 justify-center">
            <a
              href="#"
              className="flex items-center justify-center gap-2 px-6 py-3 bg-[#2C3E6B] text-white rounded-xl text-sm font-bold hover:bg-[#1F2D4A] transition"
            >
              <span>📱</span>
              Download for Android
            </a>
            <a
              href="#"
              className="flex items-center justify-center gap-2 px-6 py-3 bg-stone-900 text-white rounded-xl text-sm font-bold hover:bg-stone-800 transition"
            >
              <span>🍎</span>
              Download for iOS
            </a>
          </div>
        </div>

        {/* Buyer CTA */}
        <div className="bg-[#C85A32]/5 rounded-2xl p-5 border border-[#C85A32]/20 flex items-center gap-4 text-left">
          <ShoppingBag className="w-8 h-8 text-[#C85A32] flex-shrink-0" />
          <div className="flex-1">
            <p className="text-sm font-semibold text-stone-900">Looking to buy handcrafted products?</p>
            <p className="text-xs text-stone-500 mt-0.5">Explore our collection of authentic Indian crafts</p>
          </div>
          <Link
            href="/products"
            className="flex items-center gap-1.5 px-4 py-2.5 bg-[#C85A32] text-white rounded-xl text-xs font-bold hover:bg-[#B34D28] transition flex-shrink-0"
          >
            Shop <ArrowRight className="w-3.5 h-3.5" />
          </Link>
        </div>
      </div>
    </div>
  );
}
