"use client";

import React, { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import {
  ShoppingBag, Search, Globe, ShieldCheck, User,
  LogOut, ChevronDown, LayoutDashboard,
} from "lucide-react";
import { useCart } from "@/lib/cart-context";
import { useAuth } from "@/lib/auth-context";
import { SupportedLocale, UI_TRANSLATIONS } from "@/lib/i18n";

export default function Navbar({
  locale = "en",
  onLocaleChange,
}: {
  locale?: SupportedLocale;
  onLocaleChange?: (newLocale: SupportedLocale) => void;
}) {
  const router = useRouter();
  const { itemCount } = useCart();
  const { user, isLoggedIn, logout } = useAuth();
  const [searchQuery, setSearchQuery] = useState("");
  const [currentLang, setCurrentLang] = useState<SupportedLocale>(locale);
  const [showUserMenu, setShowUserMenu] = useState(false);

  const t = UI_TRANSLATIONS[currentLang];

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    if (searchQuery.trim()) {
      router.push(`/products?search=${encodeURIComponent(searchQuery.trim())}`);
    }
  };

  const handleLanguageChange = (code: SupportedLocale) => {
    setCurrentLang(code);
    if (onLocaleChange) onLocaleChange(code);
  };

  const handleLogout = () => {
    logout();
    setShowUserMenu(false);
    router.push("/");
  };

  return (
    <header className="sticky top-0 z-50 bg-[#FAF7F2]/95 backdrop-blur-md border-b border-[#E5DDD0]">
      {/* Top Notice Bar */}
      <div className="bg-[#2C3E6B] text-white text-xs py-1.5 px-4 text-center font-medium flex items-center justify-center gap-2">
        <ShieldCheck className="w-3.5 h-3.5 text-[#E09F3E]" />
        <span>Direct from Rural Artisans • 100% Fair Wage Guarantee • Authentic Handcrafted GI Crafts</span>
      </div>

      <nav className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-3.5 flex items-center justify-between gap-4">
        {/* Brand Logo */}
        <Link href="/" className="flex items-center gap-2.5 group">
          <div className="w-10 h-10 rounded-xl bg-[#C85A32] flex items-center justify-center shadow-md shadow-[#C85A32]/25 group-hover:scale-105 transition-transform">
            <span className="text-white font-serif font-black text-2xl">क</span>
          </div>
          <div>
            <span className="font-serif text-2xl font-black text-[#262220] tracking-tight">
              Kala<span className="text-[#C85A32]">Sathi</span>
            </span>
            <span className="block text-[10px] uppercase tracking-wider text-[#6B645F] font-semibold -mt-1">
              कलासाथी • Handicrafts
            </span>
          </div>
        </Link>

        {/* Search Bar */}
        <form onSubmit={handleSearch} className="hidden md:flex flex-1 max-w-md relative">
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder={t.searchPlaceholder}
            className="w-full pl-10 pr-4 py-2 bg-white border border-[#E5DDD0] rounded-full text-sm text-[#262220] placeholder-[#6B645F] focus:outline-none focus:ring-2 focus:ring-[#C85A32] focus:border-transparent transition"
          />
          <Search className="w-4 h-4 text-[#6B645F] absolute left-3.5 top-1/2 -translate-y-1/2" />
        </form>

        {/* Navigation Actions */}
        <div className="flex items-center gap-3">
          {/* Language Switcher */}
          <div className="relative flex items-center bg-white border border-[#E5DDD0] rounded-full px-2.5 py-1 text-xs font-semibold text-[#262220]">
            <Globe className="w-3.5 h-3.5 mr-1.5 text-[#2C3E6B]" />
            <select
              value={currentLang}
              onChange={(e) => handleLanguageChange(e.target.value as SupportedLocale)}
              className="bg-transparent focus:outline-none cursor-pointer pr-1"
            >
              <option value="en">English</option>
              <option value="hi">हिन्दी</option>
              <option value="mr">मराठी</option>
            </select>
          </div>

          {/* Explore Link */}
          <Link
            href="/products"
            className="hidden sm:inline-block text-sm font-semibold text-[#262220] hover:text-[#C85A32] transition"
          >
            {t.exploreCrafts}
          </Link>

          {/* Auth Controls */}
          {isLoggedIn && user ? (
            // Logged-in buyer menu
            <div className="relative">
              <button
                id="user-menu-btn"
                onClick={() => setShowUserMenu(!showUserMenu)}
                className="hidden sm:flex items-center gap-2 px-3.5 py-1.5 rounded-full bg-white border border-[#E5DDD0] text-xs font-semibold text-[#262220] hover:border-[#C85A32] transition"
              >
                <div className="w-5 h-5 rounded-full bg-[#C85A32]/15 flex items-center justify-center">
                  <User className="w-3 h-3 text-[#C85A32]" />
                </div>
                <span className="max-w-[80px] truncate">{user.name.split(" ")[0]}</span>
                <ChevronDown className={`w-3 h-3 text-stone-400 transition-transform ${showUserMenu ? "rotate-180" : ""}`} />
              </button>

              {showUserMenu && (
                <>
                  <div className="fixed inset-0 z-10" onClick={() => setShowUserMenu(false)} />
                  <div className="absolute right-0 top-full mt-2 w-52 bg-white rounded-2xl shadow-xl border border-stone-100 overflow-hidden z-20">
                    <div className="px-4 py-3 border-b border-stone-100 bg-stone-50">
                      <p className="text-xs font-semibold text-stone-900 truncate">{user.name}</p>
                      <p className="text-[11px] text-stone-500">Buyer Account</p>
                    </div>
                    <Link
                      href="/account"
                      onClick={() => setShowUserMenu(false)}
                      className="flex items-center gap-2.5 px-4 py-3 text-sm text-stone-700 hover:bg-stone-50 transition"
                    >
                      <LayoutDashboard className="w-4 h-4 text-[#2C3E6B]" />
                      My Account
                    </Link>
                    <Link
                      href="/account"
                      onClick={() => setShowUserMenu(false)}
                      className="flex items-center gap-2.5 px-4 py-3 text-sm text-stone-700 hover:bg-stone-50 transition border-t border-stone-100"
                    >
                      <ShoppingBag className="w-4 h-4 text-[#C85A32]" />
                      My Orders
                    </Link>
                    <button
                      id="logout-btn"
                      onClick={handleLogout}
                      className="w-full flex items-center gap-2.5 px-4 py-3 text-sm text-red-600 hover:bg-red-50 transition border-t border-stone-100"
                    >
                      <LogOut className="w-4 h-4" />
                      Sign Out
                    </button>
                  </div>
                </>
              )}
            </div>
          ) : (
            // Not logged in
            <div className="hidden sm:flex items-center gap-2">
              <Link
                id="nav-login"
                href="/login"
                className="px-3.5 py-1.5 rounded-full text-xs font-semibold text-[#262220] border border-[#E5DDD0] bg-white hover:border-[#C85A32] hover:text-[#C85A32] transition"
              >
                Sign In
              </Link>
              <Link
                id="nav-signup"
                href="/signup"
                className="px-3.5 py-1.5 rounded-full text-xs font-bold bg-[#C85A32] text-white hover:bg-[#B34D28] transition"
              >
                Get Started
              </Link>
            </div>
          )}

          {/* Cart Button */}
          <Link
            href="/cart"
            className="relative flex items-center justify-center w-10 h-10 rounded-full bg-white border border-[#E5DDD0] text-[#262220] hover:border-[#C85A32] transition"
          >
            <ShoppingBag className="w-5 h-5 text-[#2C3E6B]" />
            {itemCount > 0 && (
              <span className="absolute -top-1.5 -right-1.5 bg-[#C85A32] text-white text-[11px] font-bold w-5 h-5 rounded-full flex items-center justify-center shadow">
                {itemCount}
              </span>
            )}
          </Link>
        </div>
      </nav>
    </header>
  );
}
