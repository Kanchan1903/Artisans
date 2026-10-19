"use client";

import React, { useState } from "react";
import Link from "next/link";
import {
  Heart,
  ShieldCheck,
  LayoutDashboard,
  LogIn,
  Package,
  RotateCcw,
  Truck,
  HelpCircle,
  FileText,
  Mail,
  MapPin,
  ExternalLink,
} from "lucide-react";
import { useAuth } from "@/lib/auth-context";
import { useLanguage } from "@/lib/language-context";

export default function Footer() {
  const { isLoggedIn, isArtisan, user } = useAuth();
  const { t } = useLanguage();
  const [infoModal, setInfoModal] = useState<{ title: string; content: string } | null>(null);

  const openPolicy = (title: string, content: string) => {
    setInfoModal({ title, content });
  };

  return (
    <>
      <footer className="bg-[#1C2536] text-white pt-16 pb-8 border-t border-[#2A374F]">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          {/* Main 4-Column Grid */}
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-10 pb-12 border-b border-white/10">
            {/* Col 1: Brand & Customer Story (2 cols wide on desktop) */}
            <div className="lg:col-span-2 space-y-4">
              <Link href="/" className="flex items-center gap-2.5">
                <div className="w-9 h-9 rounded-xl bg-[#C85A32] flex items-center justify-center font-serif font-black text-white text-xl shadow-md">
                  क
                </div>
                <div>
                  <span className="font-serif text-2xl font-black text-white tracking-tight">
                    Kala<span className="text-[#E09F3E]">Sathi</span>
                  </span>
                  <span className="block text-[10px] uppercase tracking-wider text-white/60 font-semibold -mt-1">
                    Authentic Indian Handicrafts Marketplace
                  </span>
                </div>
              </Link>

              <p className="text-white/70 text-xs sm:text-sm leading-relaxed max-w-sm">
                Discover unique handmade treasures, thoughtful gifts, and timeless Indian craftsmanship sourced directly from master artisans and rural craft clusters across India.
              </p>

              {/* Trust Badges */}
              <div className="flex flex-wrap gap-2 pt-1">
                <div className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-white/5 border border-white/10 text-xs font-semibold text-[#E09F3E]">
                  <ShieldCheck className="w-3.5 h-3.5 text-[#E09F3E]" />
                  <span>Verified Craft Clusters</span>
                </div>
                <div className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-white/5 border border-white/10 text-xs font-semibold text-white/80">
                  <Truck className="w-3.5 h-3.5 text-[#C85A32]" />
                  <span>Direct Artisan Shipping</span>
                </div>
              </div>
            </div>

            {/* Col 2: Shop by Craft Category */}
            <div>
              <h4 className="text-white font-bold text-xs uppercase tracking-wider text-[#E09F3E] mb-4">
                {t("categories", "Categories")}
              </h4>
              <ul className="space-y-2.5 text-xs text-white/70 font-medium">
                <li>
                  <Link href="/products?category_id=3" className="hover:text-white transition flex items-center gap-1">
                    <span>Pottery &amp; Terracotta</span>
                  </Link>
                </li>
                <li>
                  <Link href="/products?category_id=4" className="hover:text-white transition flex items-center gap-1">
                    <span>Handloom &amp; Textiles</span>
                  </Link>
                </li>
                <li>
                  <Link href="/products?category_id=5" className="hover:text-white transition flex items-center gap-1">
                    <span>Jewelry &amp; Metalcraft</span>
                  </Link>
                </li>
                <li>
                  <Link href="/products?category_id=1" className="hover:text-white transition flex items-center gap-1">
                    <span>Tribal &amp; Folk Art</span>
                  </Link>
                </li>
                <li>
                  <Link href="/products?category_id=2" className="hover:text-white transition flex items-center gap-1">
                    <span>Woodcraft &amp; Toys</span>
                  </Link>
                </li>
                <li>
                  <Link href="/products" className="text-[#E09F3E] hover:underline font-bold pt-1 inline-block">
                    {t("shopAll", "View All Products →")}
                  </Link>
                </li>
              </ul>
            </div>

            {/* Col 3: Customer Care & Policies */}
            <div>
              <h4 className="text-white font-bold text-xs uppercase tracking-wider text-[#E09F3E] mb-4">
                Customer Care
              </h4>
              <ul className="space-y-2.5 text-xs text-white/70 font-medium">
                <li>
                  <Link href="/account" className="hover:text-white transition">
                    Track Orders &amp; Delivery
                  </Link>
                </li>
                <li>
                  <button
                    onClick={() =>
                      openPolicy(
                        "Shipping Policy",
                        "All items on KalaSathi are handcrafted and packaged directly by our partner artisans or regional cooperative clusters. Orders typically ship within 2-4 business days, with real-time tracking updates sent directly to your account and phone."
                      )
                    }
                    className="hover:text-white transition text-left"
                  >
                    {t("shippingPolicy", "Shipping Policy")}
                  </button>
                </li>
                <li>
                  <button
                    onClick={() =>
                      openPolicy(
                        "Returns & Exchange",
                        "We stand behind the authenticity of every handmade item. Because each product is uniquely handcrafted by rural artisans, returns are accepted within 7 days of delivery for damaged or defective items with photographic proof."
                      )
                    }
                    className="hover:text-white transition text-left"
                  >
                    {t("returnsPolicy", "Returns & Exchange")}
                  </button>
                </li>
                <li>
                  <button
                    onClick={() =>
                      openPolicy(
                        "Frequently Asked Questions (FAQs)",
                        "1. Are these genuine handmade products? Yes, 100% crafted by master artisans across India.\n\n2. How do artisans get paid? 100% of the artisan's listed price goes directly to their bank account with zero middlemen deductions.\n\n3. Can I request customized or bulk gifts? Yes! Use the inquiry option on product pages for bespoke wedding or corporate gifting."
                      )
                    }
                    className="hover:text-white transition text-left"
                  >
                    {t("faqs", "FAQs")}
                  </button>
                </li>
                <li>
                  <button
                    onClick={() =>
                      openPolicy(
                        "Privacy Policy",
                        "KalaSathi respects customer privacy. We securely store your account credentials, shipping addresses, and order history using industry-standard encryption. We never sell your personal contact details to third parties."
                      )
                    }
                    className="hover:text-white transition text-left"
                  >
                    {t("privacyPolicy", "Privacy Policy")}
                  </button>
                </li>
                <li>
                  <button
                    onClick={() =>
                      openPolicy(
                        "Terms of Service",
                        "By using the KalaSathi marketplace, buyers agree to authentic fair-trade commerce. All transactions are securely processed in Indian Rupees (INR) or supported currencies."
                      )
                    }
                    className="hover:text-white transition text-left"
                  >
                    {t("termsOfService", "Terms of Service")}
                  </button>
                </li>
              </ul>
            </div>

            {/* Col 4: Account & Artisan Hub */}
            <div>
              <h4 className="text-white font-bold text-xs uppercase tracking-wider text-[#E09F3E] mb-4">
                My Account
              </h4>
              <div className="space-y-2.5 text-xs text-white/70 font-medium">
                {isLoggedIn && user ? (
                  <>
                    <p className="text-white/90 font-bold truncate">Hi, {user.name}</p>
                    <Link href="/account" className="block hover:text-white transition">
                      {t("myAccount", "My Orders & Wishlist")}
                    </Link>
                    <Link href="/cart" className="block hover:text-white transition">
                      {t("cart", "Shopping Bag")}
                    </Link>
                    {isArtisan && (
                      <Link href="/artisan/dashboard" className="block text-[#E09F3E] font-bold hover:underline">
                        Artisan Dashboard
                      </Link>
                    )}
                  </>
                ) : (
                  <>
                    <Link href="/login" className="block hover:text-white transition">
                      {t("signIn", "Customer Sign In")}
                    </Link>
                    <Link href="/login?tab=signup" className="block hover:text-white transition">
                      {t("createAccount", "Create Customer Account")}
                    </Link>
                    <div className="pt-2 border-t border-white/10">
                      <p className="text-[11px] text-white/50 mb-1.5">Are you an artisan?</p>
                      <Link
                        href="/login"
                        className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-white/10 hover:bg-white/15 text-white text-[11px] font-semibold transition"
                      >
                        <LogIn className="w-3 h-3 text-[#E09F3E]" />
                        <span>Artisan Portal</span>
                      </Link>
                    </div>
                  </>
                )}
              </div>
            </div>
          </div>

          {/* Bottom Bar */}
          <div className="pt-8 flex flex-col sm:flex-row items-center justify-between text-xs text-white/50 gap-4">
            <p>{t("footerRights", "© 2026 KalaSathi Platform. Built with care for Indian Artisans.")}</p>
            <div className="flex items-center gap-6">
              <Link href="/products" className="hover:text-white transition">
                {t("shopAll", "Shop All")}
              </Link>
              <span>•</span>
              <button
                onClick={() =>
                  openPolicy(
                    "Contact Us",
                    "Email: support@kalasathi.in\nHelpline: +91 1800-KALA-SATHI\nHeadquarters: KalaSathi Artisan Support Center, New Delhi & Pune, India"
                  )
                }
                className="hover:text-white transition"
              >
                {t("contactUs", "Contact Us")}
              </button>
              <span>•</span>
              <span className="flex items-center gap-1 text-white/70">
                Crafted with <Heart className="w-3.5 h-3.5 text-[#C85A32] fill-[#C85A32]" /> for Indian Heritage
              </span>
            </div>
          </div>
        </div>
      </footer>

      {/* Info / Policy Modal */}
      {infoModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm animate-in fade-in">
          <div className="bg-white rounded-3xl p-6 sm:p-8 max-w-lg w-full shadow-2xl border border-stone-200">
            <h3 className="font-serif text-2xl font-black text-stone-900 mb-3">
              {infoModal.title}
            </h3>
            <p className="text-sm text-stone-600 leading-relaxed whitespace-pre-line mb-6">
              {infoModal.content}
            </p>
            <div className="flex justify-end">
              <button
                onClick={() => setInfoModal(null)}
                className="px-5 py-2.5 rounded-full bg-[#C85A32] hover:bg-[#B34D28] text-white text-xs font-bold transition shadow-md"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
