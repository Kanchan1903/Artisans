"use client";

import React, { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import {
  ShoppingBag,
  Search,
  Globe,
  User,
  LogOut,
  ChevronDown,
  LayoutDashboard,
} from "lucide-react";
import { useCart } from "@/lib/cart-context";
import { useAuth } from "@/lib/auth-context";
import { useLanguage } from "@/lib/language-context";
import { SupportedLocale } from "@/lib/i18n";

export default function Navbar() {
  const router = useRouter();
  const { itemCount } = useCart();
  const { user, isLoggedIn, logout } = useAuth();
  const { locale, setLocale, t, languages } = useLanguage();

  const [searchQuery, setSearchQuery] = useState("");
  const [showUserMenu, setShowUserMenu] = useState(false);
  const [showLangMenu, setShowLangMenu] = useState(false);

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    if (searchQuery.trim()) {
      router.push(`/products?search=${encodeURIComponent(searchQuery.trim())}`);
    }
  };

  const handleLogout = () => {
    logout();
    setShowUserMenu(false);
    router.push("/login");
  };

  const activeLang = languages.find((l) => l.code === locale) || languages[0];

  return (
    <header className="sticky top-0 z-50 bg-[#FAF7F2]/95 backdrop-blur-md border-b border-[#E5DDD0]">
      <nav className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-3.5 flex items-center justify-between gap-4">
        {/* Brand Logo */}
        <Link href="/" className="flex items-center gap-2.5 group flex-shrink-0">
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
            placeholder={t("searchPlaceholder", "Search handmade pottery, warli paintings, woodcraft...")}
            className="w-full pl-10 pr-4 py-2 bg-white border border-[#E5DDD0] rounded-full text-sm text-[#262220] placeholder-[#6B645F] focus:outline-none focus:ring-2 focus:ring-[#C85A32] focus:border-transparent transition"
          />
          <Search className="w-4 h-4 text-[#6B645F] absolute left-3.5 top-1/2 -translate-y-1/2" />
        </form>

        {/* Navigation Actions */}
        <div className="flex items-center gap-3">
          {/* 12-Language Switcher Dropdown */}
          <div className="relative">
            <button
              id="lang-select-btn"
              onClick={() => setShowLangMenu(!showLangMenu)}
              className="flex items-center gap-1.5 bg-white border border-[#E5DDD0] rounded-full px-3 py-1.5 text-xs font-semibold text-[#262220] hover:border-[#C85A32] transition shadow-sm"
              title="Change Language / भाषा बदलें"
            >
              <Globe className="w-3.5 h-3.5 text-[#2C3E6B]" />
              <span>{activeLang.native}</span>
              <ChevronDown className={`w-3 h-3 text-stone-400 transition-transform ${showLangMenu ? "rotate-180" : ""}`} />
            </button>

            {showLangMenu && (
              <>
                <div className="fixed inset-0 z-40" onClick={() => setShowLangMenu(false)} />
                <div className="absolute right-0 top-full mt-2 w-56 bg-white rounded-2xl shadow-2xl border border-stone-200 overflow-hidden z-50 py-2 max-h-96 overflow-y-auto">
                  <div className="px-3 py-1.5 text-[10px] uppercase font-bold text-stone-400 tracking-wider border-b border-stone-100">
                    Select Language (12 Indian Languages)
                  </div>
                  {languages.map((lang) => (
                    <button
                      key={lang.code}
                      onClick={() => {
                        setLocale(lang.code);
                        setShowLangMenu(false);
                      }}
                      className={`w-full px-4 py-2.5 text-left text-xs flex items-center justify-between hover:bg-[#FBECE6] transition ${
                        locale === lang.code ? "bg-[#FBECE6]/60 text-[#C85A32] font-bold" : "text-stone-700"
                      }`}
                    >
                      <span className="text-sm font-medium">{lang.native}</span>
                      <span className="text-[11px] text-stone-400 font-sans">{lang.name}</span>
                    </button>
                  ))}
                </div>
              </>
            )}
          </div>

          {/* Explore Link */}
          <Link
            href="/products"
            className="hidden sm:inline-block text-sm font-semibold text-[#262220] hover:text-[#C85A32] transition"
          >
            {t("exploreCrafts", "Explore Crafts")}
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
                  <div className="fixed inset-0 z-40" onClick={() => setShowUserMenu(false)} />
                  <div className="absolute right-0 top-full mt-2 w-52 bg-white rounded-2xl shadow-xl border border-stone-100 overflow-hidden z-50">
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
                      {t("myAccount", "My Account")}
                    </Link>
                    <Link
                      href="/account"
                      onClick={() => setShowUserMenu(false)}
                      className="flex items-center gap-2.5 px-4 py-3 text-sm text-stone-700 hover:bg-stone-50 transition border-t border-stone-100"
                    >
                      <ShoppingBag className="w-4 h-4 text-[#C85A32]" />
                      {t("myOrders", "My Orders")}
                    </Link>
                    <button
                      id="logout-btn"
                      onClick={handleLogout}
                      className="w-full flex items-center gap-2.5 px-4 py-3 text-sm text-red-600 hover:bg-red-50 transition border-t border-stone-100"
                    >
                      <LogOut className="w-4 h-4" />
                      {t("signOut", "Sign Out")}
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
                {t("signIn", "Sign In")}
              </Link>
              <Link
                id="nav-signup"
                href="/login"
                className="px-3.5 py-1.5 rounded-full text-xs font-bold bg-[#C85A32] text-white hover:bg-[#B34D28] transition"
              >
                {t("createAccount", "Create Account")}
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
