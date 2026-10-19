"use client";

import React, { useEffect, useState } from "react";
import Link from "next/link";
import {
  Sparkles,
  ArrowRight,
  ShieldCheck,
  Heart,
  ShoppingBag,
  Gift,
  Check,
  Lock,
  Tag,
  Award,
  Layers,
  MapPin,
} from "lucide-react";
import {
  fetchProducts,
  fetchCategories,
  fetchArtisans,
  fetchMyWishlist,
  toggleWishlist,
  Product,
  Category,
  ArtisanPublic,
  API_BASE_URL,
} from "@/lib/api";
import { useCart } from "@/lib/cart-context";
import { useAuth } from "@/lib/auth-context";
import { useLanguage } from "@/lib/language-context";

// Curated authentic craft photography for categories
const CATEGORY_IMAGES: Record<string, string> = {
  pottery: "https://images.unsplash.com/photo-1578749556568-bc2c40e68b61?w=800&auto=format&fit=crop&q=80",
  handloom: "https://images.unsplash.com/photo-1610030469983-98e550d6193c?w=800&auto=format&fit=crop&q=80",
  jewelry: "https://images.unsplash.com/photo-1535632066927-ab7c9ab60908?w=800&auto=format&fit=crop&q=80",
  "folk-art": "https://images.unsplash.com/photo-1579783902614-a3fb3927b675?w=800&auto=format&fit=crop&q=80",
  woodcraft: "https://images.unsplash.com/photo-1513519245088-0e12902e5a38?w=800&auto=format&fit=crop&q=80",
};

export default function HomePage() {
  const { addToCart } = useCart();
  const { isLoggedIn, token } = useAuth();
  const { t } = useLanguage();

  const [products, setProducts] = useState<Product[]>([]);
  const [categories, setCategories] = useState<Category[]>([]);
  const [artisans, setArtisans] = useState<ArtisanPublic[]>([]);
  const [wishlistIds, setWishlistIds] = useState<Set<number>>(new Set());
  const [addedIds, setAddedIds] = useState<Set<number>>(new Set());
  const [liveNotification, setLiveNotification] = useState<string | null>(null);

  // Load real products & categories from backend
  useEffect(() => {
    let mounted = true;
    async function loadData() {
      try {
        const [prodsRes, catsRes, artsRes] = await Promise.allSettled([
          fetchProducts({ size: 16 }),
          fetchCategories(),
          fetchArtisans(),
        ]);
        if (mounted) {
          if (prodsRes.status === "fulfilled") setProducts(prodsRes.value.items || []);
          if (catsRes.status === "fulfilled") setCategories(catsRes.value || []);
          if (artsRes.status === "fulfilled") setArtisans(artsRes.value || []);
        }
      } catch (_) {}
    }
    loadData();

    // Listen to real-time Server-Sent Events (SSE)
    try {
      const eventSource = new EventSource(`${API_BASE_URL}/events/stream`);
      eventSource.addEventListener("product_published", (e: any) => {
        try {
          const data = JSON.parse(e.data);
          setLiveNotification(`✨ New Live Craft: "${data.title}" by artisan in ${data.state || "India"}!`);
          setTimeout(() => setLiveNotification(null), 8000);
          loadData();
        } catch (_) {}
      });
      return () => {
        mounted = false;
        eventSource.close();
      };
    } catch (_) {
      return () => {
        mounted = false;
      };
    }
  }, []);

  // Load user wishlist if logged in
  useEffect(() => {
    if (!isLoggedIn || !token) {
      setWishlistIds(new Set());
      return;
    }
    let mounted = true;
    fetchMyWishlist(token)
      .then((items) => {
        if (mounted && Array.isArray(items)) {
          setWishlistIds(new Set(items.map((i) => i.product_id)));
        }
      })
      .catch(() => {});
    return () => {
      mounted = false;
    };
  }, [isLoggedIn, token]);

  const handleToggleWishlist = async (e: React.MouseEvent, productId: number) => {
    e.preventDefault();
    e.stopPropagation();
    if (!isLoggedIn || !token) {
      window.location.href = `/login?redirect=/account?tab=wishlist`;
      return;
    }
    try {
      const res = await toggleWishlist(productId, token);
      setWishlistIds((prev) => {
        const next = new Set(prev);
        if (res.wishlisted) next.add(productId);
        else next.delete(productId);
        return next;
      });
    } catch (_) {}
  };

  const handleAddToCart = (e: React.MouseEvent, prod: Product) => {
    e.preventDefault();
    e.stopPropagation();
    addToCart(prod, 1);
    setAddedIds((prev) => new Set(prev).add(prod.id));
    setTimeout(() => {
      setAddedIds((prev) => {
        const next = new Set(prev);
        next.delete(prod.id);
        return next;
      });
    }, 1500);
  };

  // Distinct curated collections without repetition
  const newArrivals = products.slice(0, 4);
  const discoverMore = products.length > 4 ? products.slice(4, 8) : [];
  const uniqueFinds = products.length > 8 ? products.slice(8, 12) : [];

  return (
    <div className="space-y-16 pb-24">
      {/* ─── Real-Time Live Notification Banner ─────────────────────────────── */}
      {liveNotification && (
        <div className="bg-[#C85A32] text-white py-3 px-4 text-center font-bold text-sm shadow-md flex items-center justify-center gap-2 animate-in fade-in">
          <Sparkles className="w-4 h-4 text-[#E09F3E]" />
          <span>{liveNotification}</span>
        </div>
      )}

      {/* ─── 1. Customer-Centric Hero Section ──────────────────────────────── */}
      <section className="relative overflow-hidden bg-gradient-to-b from-[#FAF7F2] via-[#FAF7F2] to-[#F2EBE0] border-b border-[#E5DDD0] py-16 sm:py-24">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 items-center">
            {/* Left Column: Customer-Oriented Messaging & CTAs */}
            <div className="lg:col-span-7 space-y-6">
              <div className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full bg-[#C85A32]/10 border border-[#C85A32]/25 text-[#C85A32] text-xs font-bold uppercase tracking-wider">
                <Sparkles className="w-3.5 h-3.5 text-[#C85A32]" />
                <span>Curated Indian Handicrafts Marketplace</span>
              </div>

              <h1 className="font-serif text-4xl sm:text-5xl lg:text-6xl font-black text-[#262220] leading-[1.15] tracking-tight">
                {t("heroHeadline", "Bring India's Handcrafted Stories Home")}
              </h1>

              <p className="text-base sm:text-lg text-[#6B645F] max-w-2xl leading-relaxed">
                {t(
                  "heroSub",
                  "Discover unique handmade treasures, thoughtful gifts, and timeless Indian craftsmanship. Find something special for every corner of your home and every occasion."
                )}
              </p>

              <div className="flex flex-wrap items-center gap-4 pt-2">
                <Link
                  href="/products"
                  className="inline-flex items-center gap-2 px-7 py-3.5 rounded-full bg-[#C85A32] hover:bg-[#9E3A19] text-white font-bold text-sm sm:text-base shadow-lg shadow-[#C85A32]/25 transition transform hover:-translate-y-0.5"
                >
                  <span>{t("shopHandcraftedCTA", "Shop Handcrafted Products")}</span>
                  <ArrowRight className="w-4 h-4" />
                </Link>

                <a
                  href="#categories"
                  className="inline-flex items-center gap-2 px-6 py-3.5 rounded-full bg-white hover:bg-[#FAF7F2] border border-[#E5DDD0] text-[#2C3E6B] font-bold text-sm sm:text-base shadow-sm transition"
                >
                  <Layers className="w-4 h-4 text-[#2C3E6B]" />
                  <span>{t("exploreCategoriesCTA", "Explore Categories")}</span>
                </a>
              </div>

              {/* Sub-note */}
              <div className="pt-2 text-xs text-[#8C827A] flex items-center gap-2">
                <ShieldCheck className="w-4 h-4 text-[#2C3E6B]" />
                <span>Direct from village master craftspeople across 12 Indian states</span>
              </div>
            </div>

            {/* Right Column: Authentic Indian Handicraft Showcase Hero Imagery */}
            <div className="lg:col-span-5 relative">
              <div className="relative mx-auto max-w-md rounded-3xl overflow-hidden shadow-2xl border-4 border-white bg-white">
                <img
                  src="/hero-crafts.jpg"
                  alt="Authentic Indian Handcrafted Heritage Collection"
                  className="w-full h-[400px] object-cover hover:scale-105 transition-transform duration-500"
                />
                <div className="absolute inset-0 bg-gradient-to-t from-black/85 via-black/25 to-transparent flex flex-col justify-end p-6 text-white">
                  <div className="inline-block px-2.5 py-1 rounded-full bg-[#E09F3E] text-[#262220] font-bold text-xs uppercase tracking-wide mb-2 w-max">
                    Timeless Craftsmanship
                  </div>
                  <h3 className="font-serif font-black text-xl text-white">
                    Authentic Indian Handcrafts &amp; Decor
                  </h3>
                  <p className="text-xs text-white/80 mt-1 leading-relaxed">
                    Hand-carved woodcraft, heritage brass decor, handloom textiles, and blue pottery from regional artisan clusters.
                  </p>
                  <div className="mt-3 pt-3 border-t border-white/20 flex items-center justify-between text-xs font-semibold">
                    <span className="text-[#E09F3E]">100% Genuine Artisan Origin</span>
                    <Link href="/products" className="text-white hover:underline flex items-center gap-1">
                      <span>Explore Collection</span>
                      <ArrowRight className="w-3.5 h-3.5" />
                    </Link>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* ─── 2. Customer Trust Benefits Bar ───────────────────────────────── */}
      <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 -mt-6 sm:-mt-10 relative z-20">
        <div className="bg-white rounded-2xl sm:rounded-3xl shadow-xl border border-[#E5DDD0] p-6 sm:p-8">
          <div className="grid grid-cols-2 md:grid-cols-5 gap-6 divide-y md:divide-y-0 md:divide-x divide-[#E5DDD0]/60">
            {/* Benefit 1 */}
            <div className="flex flex-col items-center text-center px-2 pt-3 md:pt-0">
              <div className="w-11 h-11 rounded-2xl bg-[#FAF7F2] flex items-center justify-center text-[#C85A32] mb-3 shadow-inner">
                <Award className="w-5 h-5 text-[#C85A32]" />
              </div>
              <h4 className="font-bold text-xs sm:text-sm text-[#262220]">
                {t("trustAuthentic", "Authentic Indian Handcrafts")}
              </h4>
              <p className="text-[11px] text-[#8C827A] mt-1 leading-relaxed">
                {t("trustAuthenticSub", "Direct from heritage craft clusters")}
              </p>
            </div>

            {/* Benefit 2 */}
            <div className="flex flex-col items-center text-center px-2 pt-3 md:pt-0">
              <div className="w-11 h-11 rounded-2xl bg-[#FAF7F2] flex items-center justify-center text-[#2C3E6B] mb-3 shadow-inner">
                <ShieldCheck className="w-5 h-5 text-[#2C3E6B]" />
              </div>
              <h4 className="font-bold text-xs sm:text-sm text-[#262220]">
                {t("trustDirect", "Directly Sourced from Artisans")}
              </h4>
              <p className="text-[11px] text-[#8C827A] mt-1 leading-relaxed">
                {t("trustDirectSub", "Fair earnings straight to master makers")}
              </p>
            </div>

            {/* Benefit 3 */}
            <div className="flex flex-col items-center text-center px-2 pt-3 md:pt-0">
              <div className="w-11 h-11 rounded-2xl bg-[#FAF7F2] flex items-center justify-center text-[#2C3E6B] mb-3 shadow-inner">
                <Lock className="w-5 h-5 text-[#2C3E6B]" />
              </div>
              <h4 className="font-bold text-xs sm:text-sm text-[#262220]">
                {t("trustSecure", "Secure Checkout")}
              </h4>
              <p className="text-[11px] text-[#8C827A] mt-1 leading-relaxed">
                {t("trustSecureSub", "Safe payments & trackable delivery")}
              </p>
            </div>

            {/* Benefit 4 */}
            <div className="flex flex-col items-center text-center px-2 pt-3 md:pt-0">
              <div className="w-11 h-11 rounded-2xl bg-[#FAF7F2] flex items-center justify-center text-[#E09F3E] mb-3 shadow-inner">
                <Gift className="w-5 h-5 text-[#E09F3E]" />
              </div>
              <h4 className="font-bold text-xs sm:text-sm text-[#262220]">
                {t("trustGifting", "Thoughtful Gifting")}
              </h4>
              <p className="text-[11px] text-[#8C827A] mt-1 leading-relaxed">
                {t("trustGiftingSub", "Meaningful handmade pieces")}
              </p>
            </div>

            {/* Benefit 5 */}
            <div className="flex flex-col items-center text-center px-2 pt-3 md:pt-0">
              <div className="w-11 h-11 rounded-2xl bg-[#FAF7F2] flex items-center justify-center text-[#C85A32] mb-3 shadow-inner">
                <Tag className="w-5 h-5 text-[#C85A32]" />
              </div>
              <h4 className="font-bold text-xs sm:text-sm text-[#262220]">
                {t("trustPricing", "Transparent Pricing")}
              </h4>
              <p className="text-[11px] text-[#8C827A] mt-1 leading-relaxed">
                {t("trustPricingSub", "Direct pricing with zero middlemen")}
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* ─── 3. Shop by Category (Interactive Image Tiles) ───────────────── */}
      <section id="categories" className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 scroll-mt-24">
        <div className="flex items-end justify-between mb-8">
          <div>
            <span className="text-xs font-bold uppercase tracking-wider text-[#C85A32]">
              Handmade Collections
            </span>
            <h2 className="font-serif text-3xl font-black text-[#262220] mt-1">
              {t("shopByCategory", "Shop by Category")}
            </h2>
            <p className="text-sm text-[#6B645F] mt-1">
              {t(
                "shopByCategorySub",
                "Explore curated collections from master craftspeople across India"
              )}
            </p>
          </div>
          <Link
            href="/products"
            className="text-xs sm:text-sm font-bold text-[#C85A32] hover:underline flex items-center gap-1 flex-shrink-0"
          >
            <span>{t("viewAll", "View All")}</span>
            <ArrowRight className="w-4 h-4" />
          </Link>
        </div>

        {/* Dynamic Category Grid */}
        <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-4 sm:gap-6">
          {categories.map((cat) => {
            const bgImg =
              CATEGORY_IMAGES[cat.slug] ||
              "https://images.unsplash.com/photo-1606744888344-493238955de0?w=800&auto=format&fit=crop&q=80";
            return (
              <Link
                key={cat.id}
                href={`/products?category_id=${cat.id}`}
                className="group relative rounded-2xl overflow-hidden aspect-[4/5] bg-stone-100 shadow-md border border-[#E5DDD0] hover:shadow-xl transition-all duration-300 flex flex-col justify-end p-4"
              >
                <img
                  src={bgImg}
                  alt={cat.name}
                  className="absolute inset-0 w-full h-full object-cover group-hover:scale-110 transition-transform duration-500"
                />
                <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-black/25 to-transparent transition-opacity group-hover:from-black/90" />
                <div className="relative z-10 text-white">
                  <h3 className="font-serif font-bold text-base sm:text-lg leading-tight group-hover:text-[#E09F3E] transition-colors">
                    {cat.name}
                  </h3>
                  {cat.name_hi && (
                    <p className="text-xs text-white/80 mt-0.5 font-medium">{cat.name_hi}</p>
                  )}
                  <div className="mt-2 inline-flex items-center gap-1 text-[11px] font-bold text-[#E09F3E] group-hover:translate-x-1 transition-transform">
                    <span>Explore</span>
                    <ArrowRight className="w-3 h-3" />
                  </div>
                </div>
              </Link>
            );
          })}
        </div>
      </section>

      {/* ─── 4. Featured Collections: New Arrivals ────────────────────────── */}
      <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-end justify-between mb-8">
          <div>
            <span className="text-xs font-bold uppercase tracking-wider text-[#C85A32]">
              Fresh from Village Workshops
            </span>
            <h2 className="font-serif text-3xl font-black text-[#262220] mt-1">
              {t("newArrivals", "New Arrivals")}
            </h2>
            <p className="text-sm text-[#6B645F] mt-1">
              {t("newArrivalsSub", "Recently crafted additions from master artisans across India")}
            </p>
          </div>
          <Link
            href="/products?sort=newest"
            className="text-xs sm:text-sm font-bold text-[#C85A32] hover:underline flex items-center gap-1 flex-shrink-0"
          >
            <span>{t("viewAll", "View All")}</span>
            <ArrowRight className="w-4 h-4" />
          </Link>
        </div>

        {/* Product Cards or Empty State */}
        {products.length === 0 ? (
          <div className="bg-white rounded-3xl p-12 text-center border border-[#E5DDD0] max-w-lg mx-auto shadow-sm">
            <div className="w-16 h-16 rounded-2xl bg-[#FAF7F2] flex items-center justify-center text-[#C85A32] mx-auto mb-4">
              <Sparkles className="w-8 h-8 text-[#C85A32]" />
            </div>
            <h3 className="font-serif text-lg font-bold text-[#262220] mb-2">
              {t("noProductsAvailable", "New Handcrafted Batches Coming Soon")}
            </h3>
            <p className="text-[#6B645F] text-xs leading-relaxed max-w-sm mx-auto mb-6">
              {t(
                "noProductsAvailableDesc",
                "Artisans are currently crafting fresh items in their workshops. Browse our categories or check back soon for the next collection drop!"
              )}
            </p>
            <Link
              href="/products"
              className="inline-flex items-center gap-2 px-6 py-2.5 rounded-full bg-[#C85A32] text-white text-xs font-bold hover:bg-[#9E3A19] transition shadow"
            >
              <span>{t("browseAllCategories", "Browse All Categories")}</span>
              <ArrowRight className="w-3.5 h-3.5" />
            </Link>
          </div>
        ) : (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
            {newArrivals.map((prod) => renderProductCard(prod))}
          </div>
        )}
      </section>

      {/* ─── 5. Featured Collection: Discover More Crafts (Popular Finds) ──── */}
      {discoverMore.length > 0 && (
        <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-end justify-between mb-8">
            <div>
              <span className="text-xs font-bold uppercase tracking-wider text-[#2C3E6B]">
                Curated Heritage
              </span>
              <h2 className="font-serif text-3xl font-black text-[#262220] mt-1">
                {t("discoverMoreCrafts", "Discover More Crafts")}
              </h2>
              <p className="text-sm text-[#6B645F] mt-1">
                {t(
                  "discoverMoreCraftsSub",
                  "Authentic creations steeped in regional craft heritage"
                )}
              </p>
            </div>
            <Link
              href="/products"
              className="text-xs sm:text-sm font-bold text-[#C85A32] hover:underline flex items-center gap-1 flex-shrink-0"
            >
              <span>{t("viewAll", "View All")}</span>
              <ArrowRight className="w-4 h-4" />
            </Link>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
            {discoverMore.map((prod) => renderProductCard(prod))}
          </div>
        </section>
      )}

      {/* ─── 6. Featured Collection: Unique Handmade Finds ────────────────── */}
      {uniqueFinds.length > 0 && (
        <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-end justify-between mb-8">
            <div>
              <span className="text-xs font-bold uppercase tracking-wider text-[#E09F3E]">
                Special Editions
              </span>
              <h2 className="font-serif text-3xl font-black text-[#262220] mt-1">
                {t("uniqueHandmadeFinds", "Unique Handmade Finds")}
              </h2>
              <p className="text-sm text-[#6B645F] mt-1">
                {t("uniqueHandmadeFindsSub", "One-of-a-kind treasures crafted by hand")}
              </p>
            </div>
            <Link
              href="/products"
              className="text-xs sm:text-sm font-bold text-[#C85A32] hover:underline flex items-center gap-1 flex-shrink-0"
            >
              <span>{t("viewAll", "View All")}</span>
              <ArrowRight className="w-4 h-4" />
            </Link>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
            {uniqueFinds.map((prod) => renderProductCard(prod))}
          </div>
        </section>
      )}

      {/* ─── 7. Customer Trust & Brand Story ──────────────────────────────── */}
      <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="bg-gradient-to-br from-[#2C3E6B] to-[#1C2536] rounded-3xl p-8 sm:p-14 text-white shadow-xl relative overflow-hidden">
          <div className="relative z-10 max-w-2xl space-y-4">
            <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-white/10 text-xs font-bold text-[#E09F3E] uppercase tracking-wider">
              <Sparkles className="w-3.5 h-3.5" />
              <span>Authentic Cultural Heritage</span>
            </div>

            <h2 className="font-serif text-3xl sm:text-4xl font-black text-white leading-tight">
              {t("everyCraftStory", "Every Craft Has a Story")}
            </h2>

            <p className="text-white/80 text-sm sm:text-base leading-relaxed">
              {t(
                "everyCraftStorySub",
                "Explore handmade creations rooted in India's rich artistic traditions. Discover the people, techniques, and regional heritage behind the pieces you bring home."
              )}
            </p>

            <div className="pt-4 flex flex-wrap items-center gap-4">
              <Link
                href="/products"
                className="px-6 py-3 rounded-full bg-[#E09F3E] hover:bg-[#D49132] text-[#262220] font-bold text-xs sm:text-sm transition shadow-md"
              >
                {t("shopHandcraftedCTA", "Shop Handcrafted Products")}
              </Link>
              <Link
                href="/products"
                className="px-6 py-3 rounded-full bg-white/10 hover:bg-white/20 text-white font-bold text-xs sm:text-sm border border-white/20 transition"
              >
                {t("learnAboutMarketplace", "Learn About Our Artisans")}
              </Link>
            </div>
          </div>

          {/* Decorative background circle */}
          <div className="absolute -right-20 -bottom-20 w-80 h-80 rounded-full bg-white/5 pointer-events-none blur-2xl" />
        </div>
      </section>
    </div>
  );

  // Helper renderer for standard product card
  function renderProductCard(prod: Product) {
    const primaryImg =
      prod.images?.[0]?.url ||
      "https://images.unsplash.com/photo-1578749556568-bc2c40e68b61?w=800&auto=format&fit=crop&q=80";
    const isWishlisted = wishlistIds.has(prod.id);
    const isAdded = addedIds.has(prod.id);

    return (
      <div
        key={prod.id}
        className="bg-white rounded-2xl border border-[#E5DDD0] overflow-hidden hover:shadow-xl transition-all duration-300 group flex flex-col justify-between"
      >
        <div>
          {/* Product Image & Wishlist Button */}
          <div className="relative aspect-square bg-[#FAF7F2] overflow-hidden">
            <Link href={`/products/${prod.id}`}>
              <img
                src={primaryImg}
                alt={prod.title_en}
                className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
              />
            </Link>

            {/* Material / Category Badge */}
            {prod.material && (
              <div className="absolute top-3 left-3 bg-white/90 backdrop-blur-sm px-2.5 py-1 rounded-md text-[10px] font-bold text-[#2C3E6B] shadow-sm">
                {prod.material}
              </div>
            )}

            {/* Wishlist Toggle Button */}
            <button
              onClick={(e) => handleToggleWishlist(e, prod.id)}
              className="absolute top-3 right-3 w-8 h-8 rounded-full bg-white/90 backdrop-blur-sm flex items-center justify-center text-stone-600 hover:text-[#C85A32] shadow-sm transition hover:scale-110"
              title={isWishlisted ? "Remove from Wishlist" : "Add to Wishlist"}
              aria-label="Wishlist toggle"
            >
              <Heart
                className={`w-4 h-4 transition ${
                  isWishlisted ? "text-[#C85A32] fill-[#C85A32]" : "text-stone-400"
                }`}
              />
            </button>
          </div>

          {/* Product Info */}
          <div className="p-4 space-y-2">
            <Link href={`/products/${prod.id}`}>
              <h3 className="font-bold text-[#262220] text-sm group-hover:text-[#C85A32] transition line-clamp-1">
                {prod.title_en}
              </h3>
              {prod.title_hi && (
                <p className="text-xs text-[#6B645F] line-clamp-1">{prod.title_hi}</p>
              )}
            </Link>

            {/* Origin & Artisan Origin */}
            {prod.artisan && (
              <div className="flex items-center gap-1.5 text-xs text-[#6B645F]">
                <MapPin className="w-3 h-3 text-[#C85A32]" />
                <span className="truncate">{prod.artisan.state || "India"}</span>
                <span>•</span>
                <span className="truncate font-medium text-[#2C3E6B]">{prod.artisan.name}</span>
              </div>
            )}
          </div>
        </div>

        {/* Price & Add to Cart Action */}
        <div className="p-4 pt-0 border-t border-[#FAF7F2] flex items-center justify-between mt-2">
          <div>
            <span className="text-[10px] uppercase font-bold text-[#8C827A] block">
              {t("fairPrice", "Fair Price")}
            </span>
            <span className="text-lg font-black text-[#C85A32]">₹ {prod.price}</span>
          </div>

          <button
            onClick={(e) => handleAddToCart(e, prod)}
            className={`p-2.5 rounded-xl transition flex items-center justify-center shadow ${
              isAdded
                ? "bg-emerald-600 text-white"
                : "bg-[#C85A32] hover:bg-[#9E3A19] text-white"
            }`}
            title={isAdded ? "Added to Cart" : t("addToCart", "Add to Cart")}
          >
            {isAdded ? <Check className="w-4 h-4" /> : <ShoppingBag className="w-4 h-4" />}
          </button>
        </div>
      </div>
    );
  }
}
