"use client";

import React from "react";
import Link from "next/link";
import { Heart, ShieldCheck, LayoutDashboard, LogIn } from "lucide-react";
import { useAuth } from "@/lib/auth-context";
import { useLanguage } from "@/lib/language-context";

export default function Footer() {
  const { isLoggedIn, isArtisan, user } = useAuth();
  const { t } = useLanguage();

  return (
    <footer className="bg-[#1F2D4A] text-white pt-14 pb-8 border-t border-[#2C3E6B]">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-10 pb-12 border-b border-white/10">
          {/* Brand & Story */}
          <div className="md:col-span-1">
            <div className="flex items-center gap-2 mb-3">
              <div className="w-8 h-8 rounded-lg bg-[#C85A32] flex items-center justify-center font-serif font-black text-white text-lg">
                क
              </div>
              <span className="font-serif text-2xl font-black text-white">{t("brand", "KalaSathi")}</span>
            </div>
            <p className="text-white/70 text-sm leading-relaxed mb-4">
              {t("heroSubtitle", "AI-powered ethical e-commerce bridge digitizing rural Indian master artisans through photo and voice.")}
            </p>
            <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-white/10 text-xs font-semibold text-[#E09F3E]">
              <ShieldCheck className="w-3.5 h-3.5" />
              <span>Certified Fair Trade &amp; GI Heritage</span>
            </div>
          </div>

          {/* Featured Craft Traditions */}
          <div>
            <h4 className="text-white font-bold text-sm tracking-wider uppercase mb-4 text-[#E09F3E]">
              {t("allTraditions", "Craft Traditions")}
            </h4>
            <ul className="space-y-2 text-sm text-white/70">
              <li><Link href="/products?search=Warli" className="hover:text-white transition">Warli Folk Art (Maharashtra)</Link></li>
              <li><Link href="/products?search=Madhubani" className="hover:text-white transition">Madhubani Painting (Bihar)</Link></li>
              <li><Link href="/products?search=Channapatna" className="hover:text-white transition">Channapatna Toys (Karnataka)</Link></li>
              <li><Link href="/products?search=Terracotta" className="hover:text-white transition">Terracotta Pottery (Bengal)</Link></li>
              <li><Link href="/products?search=Dhokra" className="hover:text-white transition">Dhokra Brass Craft (Odisha)</Link></li>
            </ul>
          </div>

          {/* Regional Heritage */}
          <div>
            <h4 className="text-white font-bold text-sm tracking-wider uppercase mb-4 text-[#E09F3E]">
              {t("shopByState", "Shop by State")}
            </h4>
            <ul className="space-y-2 text-sm text-white/70">
              <li><Link href="/products?state=Maharashtra" className="hover:text-white transition">Maharashtra</Link></li>
              <li><Link href="/products?state=Bihar" className="hover:text-white transition">Bihar</Link></li>
              <li><Link href="/products?state=Karnataka" className="hover:text-white transition">Karnataka</Link></li>
              <li><Link href="/products?state=West+Bengal" className="hover:text-white transition">West Bengal</Link></li>
              <li><Link href="/products?state=Gujarat" className="hover:text-white transition">Gujarat</Link></li>
            </ul>
          </div>

          {/* Auth-aware section */}
          <div>
            {isLoggedIn && user ? (
              // Logged-in panel
              <>
                <h4 className="text-white font-bold text-sm tracking-wider uppercase mb-4 text-[#E09F3E]">
                  My KalaSathi
                </h4>
                <div className="space-y-3">
                  <Link
                    href={isArtisan ? "/artisan/dashboard" : "/account"}
                    className="flex items-center gap-2.5 text-sm text-white/80 hover:text-white transition"
                  >
                    <LayoutDashboard className="w-4 h-4 text-[#E09F3E]" />
                    {isArtisan ? "Artisan Dashboard" : t("myAccount", "My Account & Orders")}
                  </Link>
                  <Link href="/products" className="flex items-center gap-2.5 text-sm text-white/80 hover:text-white transition">
                    <span className="w-4 h-4 text-[#E09F3E] flex items-center justify-center">🎨</span>
                    {t("exploreCatalog", "Explore Catalog")}
                  </Link>
                  {!isArtisan && (
                    <Link href="/cart" className="flex items-center gap-2.5 text-sm text-white/80 hover:text-white transition">
                      <span className="w-4 h-4 text-[#E09F3E] flex items-center justify-center">🛍️</span>
                      {t("shoppingCart", "Shopping Cart")}
                    </Link>
                  )}
                  <div className="pt-2 border-t border-white/10">
                    <p className="text-xs text-white/50">Signed in as <span className="text-white/70 font-medium">{user.name}</span></p>
                    <p className="text-xs text-white/40 capitalize mt-0.5">{user.role}</p>
                  </div>
                </div>
              </>
            ) : (
              // Logged-out artisan CTA
              <>
                <h4 className="text-white font-bold text-sm tracking-wider uppercase mb-4 text-[#E09F3E]">
                  For Artisans
                </h4>
                <p className="text-sm text-white/70 leading-relaxed mb-4">
                  Are you an artisan? Download our mobile app to publish products in your native language with voice and photo.
                </p>
                <div className="space-y-2">
                  <Link
                    href="/login"
                    className="flex items-center gap-2 w-full px-4 py-2.5 rounded-xl bg-white/10 border border-white/20 text-white text-xs font-semibold hover:bg-white/15 transition"
                  >
                    <LogIn className="w-3.5 h-3.5" />
                    {t("signIn", "Sign In")}
                  </Link>
                </div>
                <div className="mt-4 p-3 bg-white/5 rounded-xl border border-white/10 text-xs text-white/80">
                  <span className="font-bold text-[#E09F3E]">12 Languages:</span> Speak in your native tongue. Instant AI price calculation.
                </div>
              </>
            )}
          </div>
        </div>

        {/* Bottom Bar */}
        <div className="pt-8 flex flex-col sm:flex-row items-center justify-between text-xs text-white/50 gap-4">
          <p>{t("footerRights", "© 2026 KalaSathi Platform. Built with care for Indian Artisans.")}</p>
          <div className="flex items-center gap-6">
            <Link href="/products" className="hover:text-white transition">{t("exploreCrafts", "Explore Crafts")}</Link>
            <span>•</span>
            <Link href="/artisans/1" className="hover:text-white transition">{t("meetMakers", "Meet Artisans")}</Link>
            <span>•</span>
            <span className="flex items-center gap-1">
              Crafted with <Heart className="w-3.5 h-3.5 text-[#C85A32] fill-[#C85A32]" /> across India
            </span>
          </div>
        </div>
      </div>
    </footer>
  );
}
