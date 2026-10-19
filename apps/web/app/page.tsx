"use client";

import React, { useEffect, useState } from "react";
import Link from "next/link";
import { Sparkles, ArrowRight, ShieldCheck, Heart, MapPin, Eye, ShoppingBag, LayoutDashboard } from "lucide-react";
import { fetchProducts, fetchCategories, fetchArtisans, Product, Category, ArtisanPublic, API_BASE_URL } from "@/lib/api";
import { useCart } from "@/lib/cart-context";
import { useAuth } from "@/lib/auth-context";

export default function HomePage() {
  const { addToCart } = useCart();
  const { isLoggedIn, isArtisan, user } = useAuth();
  const [products, setProducts] = useState<Product[]>([]);
  const [categories, setCategories] = useState<Category[]>([]);
  const [artisans, setArtisans] = useState<ArtisanPublic[]>([]);
  const [liveNotification, setLiveNotification] = useState<string | null>(null);

  useEffect(() => {
    async function loadData() {
      const [prodsData, cats, arts] = await Promise.all([
        fetchProducts({ size: 8 }),
        fetchCategories(),
        fetchArtisans(),
      ]);
      setProducts(prodsData.items);
      setCategories(cats);
      setArtisans(arts);
    }
    loadData();

    // Listen to real-time Server-Sent Events (SSE) from the FastAPI backend!
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
      return () => eventSource.close();
    } catch (_) {}
  }, []);

  return (
    <div className="space-y-16 pb-20">
      {/* ─── Real-Time Live Notification Banner ─────────────────────────────── */}
      {liveNotification && (
        <div className="bg-[#C85A32] text-white py-3 px-4 text-center font-bold text-sm shadow-md flex items-center justify-center gap-2 animate-bounce">
          <Sparkles className="w-4 h-4 text-[#E09F3E]" />
          <span>{liveNotification}</span>
        </div>
      )}

      {/* ─── Hero Section ─────────────────────────────────────────────────── */}
      <section className="relative overflow-hidden bg-gradient-to-b from-[#FAF7F2] to-[#F3EFE6] border-b border-[#E5DDD0] py-16 sm:py-24">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 items-center">
            {/* Left Hero Text */}
            <div className="lg:col-span-7 space-y-6">
              <div className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full bg-[#C85A32]/10 border border-[#C85A32]/20 text-[#C85A32] text-xs font-bold uppercase tracking-wider">
                <Sparkles className="w-3.5 h-3.5" />
                <span>AI Voice + Photo Digitization for Indian Artisans</span>
              </div>

              <h1 className="font-serif text-4xl sm:text-5xl lg:text-6xl font-black text-[#262220] leading-[1.1] tracking-tight">
                Authentic Crafts Direct from Rural{" "}
                <span className="text-[#C85A32]">Master Artisans</span>
              </h1>

              <p className="text-lg text-[#6B645F] max-w-2xl leading-relaxed">
                Rural artisans digitize their timeless creations in 12 Indian languages using only photo and voice.
                Every purchase ensures statutory fair labor wages and zero middlemen exploitation.
              </p>

              <div className="flex flex-wrap items-center gap-4 pt-2">
                <Link
                  href="/products"
                  className="inline-flex items-center gap-2 px-7 py-3.5 rounded-full bg-[#C85A32] hover:bg-[#9E3A19] text-white font-bold text-base shadow-lg shadow-[#C85A32]/25 transition transform hover:-translate-y-0.5"
                >
                  <span>Explore 2026 Collection</span>
                  <ArrowRight className="w-4 h-4" />
                </Link>

                {isLoggedIn ? (
                  <Link
                    href="/account"
                    className="inline-flex items-center gap-2 px-6 py-3.5 rounded-full bg-white hover:bg-[#FAF7F2] border border-[#E5DDD0] text-[#2C3E6B] font-bold text-base transition"
                  >
                    <span>My Account</span>
                  </Link>
                ) : (
                  <Link
                    href="/login"
                    className="inline-flex items-center gap-2 px-6 py-3.5 rounded-full bg-white hover:bg-[#FAF7F2] border border-[#E5DDD0] text-[#2C3E6B] font-bold text-base transition"
                  >
                    <span>Sign In</span>
                  </Link>
                )}
              </div>


              {/* Trust Metrics */}
              <div className="grid grid-cols-3 gap-6 pt-6 border-t border-[#E5DDD0]">
                <div>
                  <p className="font-serif text-2xl font-black text-[#2C3E6B]">12</p>
                  <p className="text-xs text-[#6B645F] font-semibold">Indian Languages</p>
                </div>
                <div>
                  <p className="font-serif text-2xl font-black text-[#C85A32]">100%</p>
                  <p className="text-xs text-[#6B645F] font-semibold">Fair Wage Verified</p>
                </div>
                <div>
                  <p className="font-serif text-2xl font-black text-[#E09F3E]">GI-Tag</p>
                  <p className="text-xs text-[#6B645F] font-semibold">Heritage Authenticity</p>
                </div>
              </div>
            </div>

            {/* Right Hero Visual Mosaic */}
            <div className="lg:col-span-5 relative">
              <div className="relative mx-auto max-w-md rounded-3xl overflow-hidden shadow-2xl border-4 border-white">
                <img
                  src="https://images.unsplash.com/photo-1582562124811-c09040d0a901?w=800"
                  alt="Warli Handcrafted Art"
                  className="w-full h-96 object-cover"
                />
                <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-black/20 to-transparent flex flex-col justify-end p-6 text-white">
                  <div className="inline-block px-2.5 py-1 rounded bg-[#E09F3E] text-[#262220] font-bold text-xs uppercase mb-2">
                    Warli Art • Maharashtra
                  </div>
                  <h3 className="font-serif font-bold text-xl">Harvest Dance Folk Canvas</h3>
                  <p className="text-xs text-white/80 mt-1">
                    Hand-painted using natural rice paste by Sunita Bai Sonawane, Palghar
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* ─── Shop By Craft Category ────────────────────────────────────────── */}
      <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-end justify-between mb-8">
          <div>
            <h2 className="font-serif text-3xl font-black text-[#262220]">Shop by Craft Tradition</h2>
            <p className="text-sm text-[#6B645F] mt-1">Centuries of indigenous Indian heritage passed down across generations</p>
          </div>
          <Link href="/products" className="text-sm font-bold text-[#C85A32] hover:underline flex items-center gap-1">
            <span>View All</span>
            <ArrowRight className="w-4 h-4" />
          </Link>
        </div>

        <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-4">
          {categories.map((cat) => (
            <Link
              key={cat.id}
              href={`/products?category_id=${cat.id}`}
              className="group p-5 bg-white rounded-2xl border border-[#E5DDD0] hover:border-[#C85A32] hover:shadow-lg transition text-center"
            >
              <div className="w-14 h-14 mx-auto mb-3 rounded-xl bg-[#FAF7F2] group-hover:bg-[#FBECE6] flex items-center justify-center text-[#C85A32] transition">
                <Sparkles className="w-6 h-6" />
              </div>
              <h3 className="font-bold text-[#262220] text-sm group-hover:text-[#C85A32] transition">
                {cat.name}
              </h3>
              {cat.name_hi && (
                <p className="text-xs text-[#6B645F] mt-0.5">{cat.name_hi}</p>
              )}
            </Link>
          ))}
        </div>
      </section>

      {/* ─── Featured Master Artisans Spotlight ────────────────────────────── */}
      <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="bg-[#2C3E6B] rounded-3xl p-8 sm:p-12 text-white">
          <div className="max-w-2xl mb-8">
            <span className="text-[#E09F3E] text-xs uppercase font-bold tracking-wider">Meet The Makers</span>
            <h2 className="font-serif text-3xl font-black text-white mt-1">Featured Master Artisans</h2>
            <p className="text-white/70 text-sm mt-2">
              Every artisan on KalaSathi is verified with a "Made by" trust badge and authentic village origin.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            {artisans.map((art) => (
              <div
                key={art.id}
                className="bg-white/10 backdrop-blur-md rounded-2xl p-6 border border-white/15 flex flex-col justify-between"
              >
                <div>
                  <div className="flex items-center gap-4 mb-4">
                    <img
                      src={art.profile_photo_url || "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=400"}
                      alt={art.name}
                      className="w-16 h-16 rounded-full object-cover border-2 border-[#E09F3E]"
                    />
                    <div>
                      <h3 className="font-bold text-lg text-white">{art.name}</h3>
                      <div className="flex items-center gap-1 text-xs text-[#E09F3E]">
                        <MapPin className="w-3.5 h-3.5" />
                        <span>{art.village}, {art.state}</span>
                      </div>
                    </div>
                  </div>
                  <div className="inline-block px-2.5 py-1 rounded bg-white/10 text-xs text-white/90 font-medium mb-3">
                    {art.craft_type}
                  </div>
                  <p className="text-xs text-white/75 line-clamp-3 leading-relaxed mb-4">
                    {art.bio}
                  </p>
                </div>
                <Link
                  href={`/artisans/${art.id}`}
                  className="w-full py-2.5 px-4 rounded-xl bg-white text-[#2C3E6B] font-bold text-xs text-center hover:bg-[#FAF7F2] transition"
                >
                  View Artisan Story & Crafts ({art.product_count})
                </Link>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ─── Trending Authentic Products Grid ──────────────────────────────── */}
      <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-end justify-between mb-8">
          <div>
            <h2 className="font-serif text-3xl font-black text-[#262220]">Trending Handcrafted Creations</h2>
            <p className="text-sm text-[#6B645F] mt-1">Freshly digitized from village workshops with AI Image Studio</p>
          </div>
          <Link href="/products" className="text-sm font-bold text-[#C85A32] hover:underline flex items-center gap-1">
            <span>Explore Catalog</span>
            <ArrowRight className="w-4 h-4" />
          </Link>
        </div>

        {products.length === 0 ? (
          <div className="bg-white rounded-3xl p-12 text-center border border-[#E5DDD0] max-w-lg mx-auto">
            <div className="w-16 h-16 rounded-2xl bg-[#FAF7F2] flex items-center justify-center text-[#C85A32] mx-auto mb-4">
              <Sparkles className="w-8 h-8" />
            </div>
            <h3 className="font-serif text-lg font-bold text-stone-900 mb-1">
              No products published yet
            </h3>
            <p className="text-stone-500 text-xs leading-relaxed">
              Artisans will list their authentic handcrafted creations directly from the KalaSathi mobile app. Check back soon!
            </p>
          </div>
        ) : (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
          {products.map((prod) => {
            const primaryImg = prod.images?.[0]?.url || "https://images.unsplash.com/photo-1578749556568-bc2c40e68b61?w=800";
            return (
              <div
                key={prod.id}
                className="bg-white rounded-2xl border border-[#E5DDD0] overflow-hidden hover:shadow-xl transition group flex flex-col justify-between"
              >
                <div>
                  <Link href={`/products/${prod.id}`} className="block relative aspect-square bg-[#FAF7F2] overflow-hidden">
                    <img
                      src={primaryImg}
                      alt={prod.title_en}
                      className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
                    />
                    <div className="absolute top-3 left-3 bg-white/90 backdrop-blur-sm px-2.5 py-1 rounded-md text-[11px] font-bold text-[#2C3E6B] shadow-sm">
                      {prod.material || "Handmade"}
                    </div>
                  </Link>

                  <div className="p-4 space-y-2">
                    <Link href={`/products/${prod.id}`}>
                      <h3 className="font-bold text-[#262220] text-base group-hover:text-[#C85A32] transition line-clamp-1">
                        {prod.title_en}
                      </h3>
                      {prod.title_hi && (
                        <p className="text-xs text-[#6B645F] line-clamp-1">{prod.title_hi}</p>
                      )}
                    </Link>

                    {prod.artisan && (
                      <div className="flex items-center gap-1.5 text-xs text-[#6B645F]">
                        <span className="font-medium text-[#2C3E6B]">By {prod.artisan.name}</span>
                        <span>•</span>
                        <span>{prod.artisan.state}</span>
                      </div>
                    )}
                  </div>
                </div>

                <div className="p-4 pt-0 border-t border-[#FAF7F2] flex items-center justify-between mt-2">
                  <div>
                    <span className="text-[11px] uppercase font-bold text-[#6B645F] block">Fair Price</span>
                    <span className="text-xl font-black text-[#C85A32]">₹ {prod.price}</span>
                  </div>

                  <button
                    onClick={() => addToCart(prod, 1)}
                    className="p-2.5 rounded-xl bg-[#C85A32] hover:bg-[#9E3A19] text-white transition flex items-center justify-center shadow"
                    title="Add to Cart"
                  >
                    <ShoppingBag className="w-4 h-4" />
                  </button>
                </div>
              </div>
            );
          })}
        </div>
        )}
      </section>

      {/* ─── Fair Trade Impact Assurance ───────────────────────────────────── */}
      <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-6 p-8 bg-white rounded-3xl border border-[#E5DDD0]">
          <div className="flex items-start gap-4">
            <div className="w-12 h-12 rounded-xl bg-[#FBECE6] flex items-center justify-center text-[#C85A32] flex-shrink-0">
              <ShieldCheck className="w-6 h-6" />
            </div>
            <div>
              <h3 className="font-bold text-base text-[#262220]">Fair Wage Guaranteed</h3>
              <p className="text-xs text-[#6B645F] mt-1 leading-relaxed">
                Our AI Pricing Assistant guarantees every artisan earns at least statutory hourly wages plus full material costs.
              </p>
            </div>
          </div>

          <div className="flex items-start gap-4">
            <div className="w-12 h-12 rounded-xl bg-[#E9EDF5] flex items-center justify-center text-[#2C3E6B] flex-shrink-0">
              <Sparkles className="w-6 h-6" />
            </div>
            <div>
              <h3 className="font-bold text-base text-[#262220]">12 Indian Languages</h3>
              <p className="text-xs text-[#6B645F] mt-1 leading-relaxed">
                Product descriptions are automatically cataloged and translated into 12 native Indian scripts.
              </p>
            </div>
          </div>

          <div className="flex items-start gap-4">
            <div className="w-12 h-12 rounded-xl bg-[#FCF5E8] flex items-center justify-center text-[#E09F3E] flex-shrink-0">
              <Heart className="w-6 h-6" />
            </div>
            <div>
              <h3 className="font-bold text-base text-[#262220]">Zero Middlemen Commission</h3>
              <p className="text-xs text-[#6B645F] mt-1 leading-relaxed">
                Orders placed here directly notify the artisan on their mobile app for direct packing and shipping.
              </p>
            </div>
          </div>
        </div>
      </section>
    </div>
  );
}
