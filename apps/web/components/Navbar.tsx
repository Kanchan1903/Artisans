"use client";

import React, { useState, useEffect, useRef } from "react";
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
  Heart,
  Menu,
  X,
  Sparkles,
  Layers,
  ArrowRight,
} from "lucide-react";
import { useCart } from "@/lib/cart-context";
import { useAuth } from "@/lib/auth-context";
import { useLanguage } from "@/lib/language-context";
import { fetchCategories, Category } from "@/lib/api";

export default function Navbar() {
  const router = useRouter();
  const { itemCount } = useCart();
  const { user, isLoggedIn, logout } = useAuth();
  const { locale, setLocale, t, languages } = useLanguage();

  const [searchQuery, setSearchQuery] = useState("");
  const [categories, setCategories] = useState<Category[]>([]);
  const [showCategoriesMenu, setShowCategoriesMenu] = useState(false);
  const [showUserMenu, setShowUserMenu] = useState(false);
  const [showLangMenu, setShowLangMenu] = useState(false);
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

  const categoriesRef = useRef<HTMLDivElement>(null);

  // Fetch real categories from backend
  useEffect(() => {
    let mounted = true;
    fetchCategories()
      .then((cats) => {
        if (mounted && Array.isArray(cats)) {
          setCategories(cats);
        }
      })
      .catch(() => {});
    return () => {
      mounted = false;
    };
  }, []);

  // Close dropdowns on outside click
  useEffect(() => {
    function handleClickOutside(e: MouseEvent) {
      if (categoriesRef.current && !categoriesRef.current.contains(e.target as Node)) {
        setShowCategoriesMenu(false);
      }
    }
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    if (searchQuery.trim()) {
      router.push(`/products?search=${encodeURIComponent(searchQuery.trim())}`);
      setMobileMenuOpen(false);
    }
  };

  const handleLogout = () => {
    logout();
    setShowUserMenu(false);
    setMobileMenuOpen(false);
    router.push("/login");
  };

  const activeLang = languages.find((l) => l.code === locale) || languages[0];

  return (
    <header className="sticky top-0 z-50 bg-[#FAF7F2]/95 backdrop-blur-md border-b border-[#E5DDD0]">
      {/* Top Main Navigation Bar */}
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-3 flex items-center justify-between gap-4">
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
              कलासाथी • Marketplace
            </span>
          </div>
        </Link>

        {/* Customer Search Bar (Desktop) */}
        <form onSubmit={handleSearch} className="hidden lg:flex flex-1 max-w-xl relative mx-2">
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder={t("searchPlaceholderCustomer", "Search handmade gifts, pottery, jewellery, home decor...")}
            className="w-full pl-10 pr-4 py-2 bg-white border border-[#E5DDD0] rounded-full text-sm text-[#262220] placeholder-[#8C827A] focus:outline-none focus:ring-2 focus:ring-[#C85A32] focus:border-transparent transition shadow-inner"
          />
          <Search className="w-4 h-4 text-[#8C827A] absolute left-3.5 top-1/2 -translate-y-1/2" />
        </form>

        {/* Right Action Icons & Controls */}
        <div className="flex items-center gap-2 sm:gap-3">
          {/* 12-Language Selector Dropdown */}
          <div className="relative">
            <button
              id="lang-select-btn"
              type="button"
              onClick={() => {
                setShowLangMenu(!showLangMenu);
                setShowUserMenu(false);
                setShowCategoriesMenu(false);
              }}
              className="flex items-center gap-1.5 bg-white border border-[#E5DDD0] rounded-full px-3 py-1.5 text-xs font-semibold text-[#262220] hover:border-[#C85A32] transition shadow-sm"
              title="Change Language / भाषा बदलें"
            >
              <Globe className="w-3.5 h-3.5 text-[#2C3E6B]" />
              <span className="hidden sm:inline">{activeLang.native}</span>
              <span className="sm:hidden">{activeLang.code.toUpperCase()}</span>
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
                      type="button"
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

          {/* Customer Wishlist Icon */}
          <Link
            href="/account?tab=wishlist"
            className="flex items-center justify-center w-10 h-10 rounded-full bg-white border border-[#E5DDD0] text-[#262220] hover:border-[#C85A32] hover:text-[#C85A32] transition shadow-sm"
            title={t("wishlist", "Wishlist")}
          >
            <Heart className="w-4 h-4 text-[#C85A32]" />
          </Link>

          {/* Shopping Bag Icon with Real Count */}
          <Link
            href="/cart"
            className="relative flex items-center justify-center w-10 h-10 rounded-full bg-white border border-[#E5DDD0] text-[#262220] hover:border-[#C85A32] transition shadow-sm"
            title={t("cart", "Shopping Bag")}
          >
            <ShoppingBag className="w-4 h-4 text-[#2C3E6B]" />
            {itemCount > 0 && (
              <span className="absolute -top-1.5 -right-1.5 bg-[#C85A32] text-white text-[11px] font-bold w-5 h-5 rounded-full flex items-center justify-center shadow">
                {itemCount}
              </span>
            )}
          </Link>

          {/* Sign In / My Account */}
          {isLoggedIn && user ? (
            <div className="relative">
              <button
                id="user-menu-btn"
                onClick={() => {
                  setShowUserMenu(!showUserMenu);
                  setShowLangMenu(false);
                  setShowCategoriesMenu(false);
                }}
                className="hidden sm:flex items-center gap-2 px-3.5 py-1.5 rounded-full bg-white border border-[#E5DDD0] text-xs font-semibold text-[#262220] hover:border-[#C85A32] transition shadow-sm"
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
                  <div className="absolute right-0 top-full mt-2 w-56 bg-white rounded-2xl shadow-xl border border-stone-100 overflow-hidden z-50">
                    <div className="px-4 py-3 border-b border-stone-100 bg-[#FAF7F2]">
                      <p className="text-xs font-bold text-stone-900 truncate">{user.name}</p>
                      <p className="text-[11px] text-stone-500 capitalize">{user.role} Account</p>
                    </div>
                    <Link
                      href="/account"
                      onClick={() => setShowUserMenu(false)}
                      className="flex items-center gap-2.5 px-4 py-2.5 text-xs text-stone-700 hover:bg-stone-50 transition"
                    >
                      <LayoutDashboard className="w-4 h-4 text-[#2C3E6B]" />
                      {t("myAccount", "My Account")}
                    </Link>
                    <Link
                      href="/account"
                      onClick={() => setShowUserMenu(false)}
                      className="flex items-center gap-2.5 px-4 py-2.5 text-xs text-stone-700 hover:bg-stone-50 transition border-t border-stone-100"
                    >
                      <ShoppingBag className="w-4 h-4 text-[#C85A32]" />
                      {t("myOrders", "My Orders")}
                    </Link>
                    <Link
                      href="/account?tab=wishlist"
                      onClick={() => setShowUserMenu(false)}
                      className="flex items-center gap-2.5 px-4 py-2.5 text-xs text-stone-700 hover:bg-stone-50 transition border-t border-stone-100"
                    >
                      <Heart className="w-4 h-4 text-[#C85A32]" />
                      {t("wishlist", "Wishlist")}
                    </Link>
                    <button
                      id="logout-btn"
                      onClick={handleLogout}
                      className="w-full flex items-center gap-2.5 px-4 py-2.5 text-xs text-red-600 hover:bg-red-50 transition border-t border-stone-100"
                    >
                      <LogOut className="w-4 h-4" />
                      {t("signOut", "Sign Out")}
                    </button>
                  </div>
                </>
              )}
            </div>
          ) : (
            <div className="hidden sm:flex items-center gap-2">
              <Link
                id="nav-login"
                href="/login"
                className="px-3.5 py-1.5 rounded-full text-xs font-semibold text-[#262220] border border-[#E5DDD0] bg-white hover:border-[#C85A32] hover:text-[#C85A32] transition shadow-sm"
              >
                {t("signIn", "Sign In")}
              </Link>
              <Link
                id="nav-signup"
                href="/login?tab=signup"
                className="px-3.5 py-1.5 rounded-full text-xs font-bold bg-[#C85A32] text-white hover:bg-[#B34D28] transition shadow-sm"
              >
                {t("createAccount", "Create Account")}
              </Link>
            </div>
          )}

          {/* Mobile Menu Toggle Button */}
          <button
            onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
            className="lg:hidden p-2 rounded-xl border border-[#E5DDD0] bg-white text-[#262220] hover:text-[#C85A32] transition"
            aria-label="Toggle Navigation Menu"
          >
            {mobileMenuOpen ? <X className="w-5 h-5" /> : <Menu className="w-5 h-5" />}
          </button>
        </div>
      </div>

      {/* Customer Category & Links Navigation Bar (Desktop) */}
      <div className="hidden lg:block border-t border-[#E5DDD0]/70 bg-white/70">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-2 flex items-center justify-between text-xs font-medium text-[#262220]">
          <div className="flex items-center gap-6">
            {/* Shop All Link */}
            <Link
              href="/products"
              className="font-bold hover:text-[#C85A32] transition flex items-center gap-1.5 py-1"
            >
              <span>{t("shopAll", "Shop All")}</span>
            </Link>

            {/* Categories Dropdown */}
            <div className="relative" ref={categoriesRef}>
              <button
                type="button"
                onClick={() => setShowCategoriesMenu(!showCategoriesMenu)}
                className="hover:text-[#C85A32] transition flex items-center gap-1 py-1 font-semibold"
              >
                <Layers className="w-3.5 h-3.5 text-[#C85A32]" />
                <span>{t("categories", "Categories")}</span>
                <ChevronDown className={`w-3 h-3 transition-transform ${showCategoriesMenu ? "rotate-180" : ""}`} />
              </button>

              {showCategoriesMenu && (
                <div className="absolute left-0 top-full mt-2 w-64 bg-white rounded-2xl shadow-xl border border-stone-200 py-2 z-50 animate-in fade-in slide-in-from-top-1">
                  <div className="px-3 py-1.5 text-[10px] uppercase font-bold text-stone-400 tracking-wider border-b border-stone-100">
                    Handcraft Categories
                  </div>
                  {categories.length > 0 ? (
                    categories.map((cat) => (
                      <Link
                        key={cat.id}
                        href={`/products?category_id=${cat.id}`}
                        onClick={() => setShowCategoriesMenu(false)}
                        className="px-4 py-2.5 text-xs text-stone-700 hover:bg-[#FBECE6] hover:text-[#C85A32] flex items-center justify-between transition"
                      >
                        <span className="font-medium">{cat.name}</span>
                        {cat.name_hi && (
                          <span className="text-[11px] text-stone-400">{cat.name_hi}</span>
                        )}
                      </Link>
                    ))
                  ) : (
                    <div className="px-4 py-3 text-xs text-stone-400">Loading categories...</div>
                  )}
                  <div className="border-t border-stone-100 mt-1 pt-1">
                    <Link
                      href="/products"
                      onClick={() => setShowCategoriesMenu(false)}
                      className="px-4 py-2 text-xs font-bold text-[#C85A32] hover:bg-[#FBECE6] flex items-center justify-between"
                    >
                      <span>Explore All Products</span>
                      <ArrowRight className="w-3.5 h-3.5" />
                    </Link>
                  </div>
                </div>
              )}
            </div>

            {/* New Arrivals Link */}
            <Link
              href="/products?sort=newest"
              className="hover:text-[#C85A32] transition flex items-center gap-1.5 py-1"
            >
              <Sparkles className="w-3.5 h-3.5 text-[#E09F3E]" />
              <span>{t("newArrivals", "New Arrivals")}</span>
            </Link>
          </div>

          {/* Right Sub-links */}
          <div className="flex items-center gap-4 text-stone-500 text-[11px]">
            <span>Direct from Rural Craft Clusters</span>
            <span>•</span>
            <span className="text-[#C85A32] font-semibold">100% Verified Indian Handcrafts</span>
          </div>
        </div>
      </div>

      {/* Mobile Navigation Drawer */}
      {mobileMenuOpen && (
        <div className="lg:hidden border-t border-[#E5DDD0] bg-white px-4 py-4 space-y-4 shadow-xl">
          {/* Mobile Search */}
          <form onSubmit={handleSearch} className="relative">
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Search pottery, jewellery, decor..."
              className="w-full pl-10 pr-4 py-2 bg-[#FAF7F2] border border-[#E5DDD0] rounded-full text-xs text-[#262220] placeholder-[#8C827A] focus:outline-none focus:ring-2 focus:ring-[#C85A32]"
            />
            <Search className="w-4 h-4 text-[#8C827A] absolute left-3.5 top-1/2 -translate-y-1/2" />
          </form>

          {/* Mobile Links */}
          <div className="flex flex-col space-y-2 text-sm font-semibold text-[#262220]">
            <Link
              href="/products"
              onClick={() => setMobileMenuOpen(false)}
              className="py-2 px-3 rounded-xl hover:bg-[#FAF7F2] transition flex items-center justify-between"
            >
              <span>{t("shopAll", "Shop All")}</span>
              <ArrowRight className="w-4 h-4 text-stone-400" />
            </Link>

            <Link
              href="/products?sort=newest"
              onClick={() => setMobileMenuOpen(false)}
              className="py-2 px-3 rounded-xl hover:bg-[#FAF7F2] transition flex items-center justify-between text-[#C85A32]"
            >
              <span className="flex items-center gap-2">
                <Sparkles className="w-4 h-4" />
                {t("newArrivals", "New Arrivals")}
              </span>
              <ArrowRight className="w-4 h-4 text-stone-400" />
            </Link>

            <Link
              href="/account?tab=wishlist"
              onClick={() => setMobileMenuOpen(false)}
              className="py-2 px-3 rounded-xl hover:bg-[#FAF7F2] transition flex items-center justify-between"
            >
              <span className="flex items-center gap-2">
                <Heart className="w-4 h-4 text-[#C85A32]" />
                {t("wishlist", "Wishlist")}
              </span>
              <ArrowRight className="w-4 h-4 text-stone-400" />
            </Link>

            {/* Mobile Categories list */}
            {categories.length > 0 && (
              <div className="pt-2 border-t border-[#E5DDD0]/60">
                <div className="text-[11px] font-bold uppercase text-stone-400 px-3 pb-1">
                  Browse by Category
                </div>
                <div className="grid grid-cols-2 gap-1.5 pt-1">
                  {categories.map((cat) => (
                    <Link
                      key={cat.id}
                      href={`/products?category_id=${cat.id}`}
                      onClick={() => setMobileMenuOpen(false)}
                      className="px-3 py-2 rounded-lg bg-[#FAF7F2] text-xs text-stone-700 hover:text-[#C85A32] truncate"
                    >
                      {cat.name}
                    </Link>
                  ))}
                </div>
              </div>
            )}

            {/* Mobile Auth Links */}
            <div className="pt-3 border-t border-[#E5DDD0]/60 space-y-2">
              {isLoggedIn && user ? (
                <>
                  <div className="px-3 py-1 text-xs text-stone-500">
                    Signed in as <span className="font-bold text-stone-800">{user.name}</span>
                  </div>
                  <Link
                    href="/account"
                    onClick={() => setMobileMenuOpen(false)}
                    className="block w-full py-2 px-3 rounded-xl bg-[#FAF7F2] text-xs font-semibold text-center"
                  >
                    {t("myAccount", "My Account & Orders")}
                  </Link>
                  <button
                    onClick={handleLogout}
                    className="block w-full py-2 px-3 rounded-xl text-xs font-semibold text-red-600 text-center hover:bg-red-50"
                  >
                    {t("signOut", "Sign Out")}
                  </button>
                </>
              ) : (
                <div className="grid grid-cols-2 gap-2">
                  <Link
                    href="/login"
                    onClick={() => setMobileMenuOpen(false)}
                    className="py-2 px-3 rounded-xl border border-[#E5DDD0] text-xs font-semibold text-center"
                  >
                    {t("signIn", "Sign In")}
                  </Link>
                  <Link
                    href="/login?tab=signup"
                    onClick={() => setMobileMenuOpen(false)}
                    className="py-2 px-3 rounded-xl bg-[#C85A32] text-white text-xs font-bold text-center"
                  >
                    {t("createAccount", "Create Account")}
                  </Link>
                </div>
              )}
            </div>
          </div>
        </div>
      )}
    </header>
  );
}
