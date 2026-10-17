"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import {
  MapPin,
  Award,
  Clock,
  Sparkles,
  ShieldCheck,
  ChevronRight,
  Heart,
  ShoppingCart,
  Star,
  Check,
} from "lucide-react";
import {
  fetchArtisanById,
  fetchProducts,
  ArtisanPublic,
  Product,
  SAMPLE_ARTISANS,
  SAMPLE_PRODUCTS,
} from "@/lib/api";
import { useCart } from "@/lib/cart-context";

export default function ArtisanProfilePage({ params }: { params: { id: string } }) {
  const artisanId = Number(params.id);

  const [artisan, setArtisan] = useState<ArtisanPublic | null>(null);
  const [products, setProducts] = useState<Product[]>([]);
  const [loading, setLoading] = useState(true);

  const { addToCart } = useCart();
  const [addedId, setAddedId] = useState<number | null>(null);

  useEffect(() => {
    async function loadData() {
      setLoading(true);
      try {
        const [artisanData, productsData] = await Promise.all([
          fetchArtisanById(artisanId),
          fetchProducts(),
        ]);
        setArtisan(artisanData || SAMPLE_ARTISANS.find((a) => a.id === artisanId) || SAMPLE_ARTISANS[0]);
        const artProds = (productsData.items.length > 0 ? productsData.items : SAMPLE_PRODUCTS).filter(
          (p) => p.artisan_id === artisanId || p.artisan?.id === artisanId
        );
        setProducts(artProds.length > 0 ? artProds : SAMPLE_PRODUCTS.slice(0, 2));
      } catch (err) {
        setArtisan(SAMPLE_ARTISANS[0]);
        setProducts(SAMPLE_PRODUCTS);
      } finally {
        setLoading(false);
      }
    }
    loadData();
  }, [artisanId]);

  if (!artisan) {
    return (
      <div className="min-h-screen bg-[#FAF7F2] flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-4 border-[#C85A32] border-t-transparent"></div>
      </div>
    );
  }

  const handleAddToCart = (e: React.MouseEvent, p: Product) => {
    e.preventDefault();
    e.stopPropagation();
    addToCart(p, 1);
    setAddedId(p.id);
    setTimeout(() => setAddedId(null), 1500);
  };

  return (
    <div className="min-h-screen bg-[#FAF7F2] py-8 px-4 sm:px-6 lg:px-8">
      <div className="max-w-7xl mx-auto">
        {/* Breadcrumb */}
        <nav className="flex items-center space-x-2 text-xs text-stone-500 mb-6">
          <Link href="/" className="hover:text-[#C85A32]">Home</Link>
          <ChevronRight className="w-3 h-3 text-stone-400" />
          <Link href="/products" className="hover:text-[#C85A32]">Artisans</Link>
          <ChevronRight className="w-3 h-3 text-stone-400" />
          <span className="text-stone-800 font-medium">{artisan.name}</span>
        </nav>

        {/* ARTISAN HERO PROFILE BANNER */}
        <div className="bg-white rounded-3xl p-6 sm:p-10 border border-stone-200/80 shadow-sm mb-12 relative overflow-hidden">
          <div className="absolute top-0 right-0 w-96 h-96 bg-[#C85A32]/5 rounded-full blur-3xl pointer-events-none"></div>

          <div className="flex flex-col md:flex-row items-center md:items-start gap-8 relative z-10">
            {/* Portrait */}
            <div className="relative">
              <img
                src={
                  artisan.profile_photo_url ||
                  "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=500"
                }
                alt={artisan.name}
                className="w-36 h-36 sm:w-44 sm:h-44 rounded-3xl object-cover border-4 border-[#FAF7F2] shadow-md"
              />
              <span className="absolute -bottom-2 -right-2 bg-emerald-600 text-white p-2 rounded-full shadow-md" title="GI Verified Master Artisan">
                <ShieldCheck className="w-5 h-5" />
              </span>
            </div>

            {/* Bio & Badges */}
            <div className="flex-1 text-center md:text-left">
              <div className="flex flex-wrap items-center justify-center md:justify-start gap-2 mb-2">
                <span className="px-3 py-1 bg-[#2C3E6B]/10 text-[#2C3E6B] rounded-full text-xs font-bold">
                  {artisan.craft_type}
                </span>
                <span className="px-3 py-1 bg-emerald-50 text-emerald-700 rounded-full text-xs font-medium flex items-center space-x-1">
                  <Award className="w-3 h-3 text-emerald-600" />
                  <span>KalaSathi Guild Verified</span>
                </span>
              </div>

              <h1 className="font-serif text-3xl sm:text-4xl font-bold text-stone-900 mb-2">
                {artisan.name}
              </h1>

              <div className="flex flex-wrap items-center justify-center md:justify-start gap-4 text-xs text-stone-500 mb-4">
                <div className="flex items-center space-x-1.5">
                  <MapPin className="w-4 h-4 text-[#C85A32]" />
                  <span>
                    {artisan.village}, {artisan.district}, {artisan.state}
                  </span>
                </div>
                <div className="flex items-center space-x-1.5">
                  <Clock className="w-4 h-4 text-[#E09F3E]" />
                  <span>{artisan.years_experience || 20} Years Preserving Heritage</span>
                </div>
              </div>

              <p className="text-stone-700 text-sm sm:text-base leading-relaxed max-w-3xl mb-6">
                {artisan.bio ||
                  `Dedicated to preserving indigenous crafts passed through generations. Every artifact created by ${artisan.name} uses authentic natural materials and centuries-old artisanal wisdom.`}
              </p>

              {/* Impact Callout */}
              <div className="inline-flex items-center space-x-2 bg-amber-50 border border-amber-200/80 px-4 py-2.5 rounded-xl text-xs text-amber-900">
                <Sparkles className="w-4 h-4 text-[#E09F3E] flex-shrink-0" />
                <span>
                  <strong>100% Direct Fair Wage:</strong> Purchases from this shop empower {artisan.name}&apos;s family and local rural cluster in {artisan.village}.
                </span>
              </div>
            </div>
          </div>
        </div>

        {/* ARTISAN'S CREATIONS GRID */}
        <div>
          <div className="flex items-center justify-between mb-6">
            <div>
              <h2 className="font-serif text-2xl font-bold text-stone-900">
                Handcrafted Works by {artisan.name}
              </h2>
              <p className="text-xs text-stone-500">
                {products.length} authenticated items available for purchase
              </p>
            </div>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
            {products.map((p) => {
              const primaryImg = p.images?.[0]?.url || "https://images.unsplash.com/photo-1582562124811-c09040d0a901?w=800";
              return (
                <Link
                  key={p.id}
                  href={`/products/${p.id}`}
                  className="group bg-white rounded-2xl overflow-hidden border border-stone-200/80 shadow-sm hover:shadow-md transition-all flex flex-col justify-between"
                >
                  <div>
                    <div className="relative aspect-square w-full bg-stone-100 overflow-hidden">
                      <img
                        src={primaryImg}
                        alt={p.title_en}
                        className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
                      />
                      {p.ai_generated && (
                        <span className="absolute top-3 left-3 inline-flex items-center space-x-1 bg-white/95 backdrop-blur-sm px-2.5 py-1 rounded-full text-[11px] font-medium text-stone-800 shadow-sm">
                          <Sparkles className="w-3 h-3 text-[#E09F3E]" />
                          <span>AI Studio 1:1</span>
                        </span>
                      )}
                    </div>

                    <div className="p-5">
                      <p className="text-xs font-semibold text-[#2C3E6B] mb-1">
                        {p.artisan?.craft_type || artisan.craft_type}
                      </p>
                      <h3 className="font-serif font-bold text-stone-900 group-hover:text-[#C85A32] transition-colors line-clamp-2 text-base mb-2">
                        {p.title_en}
                      </h3>
                      <p className="text-xs text-stone-500 line-clamp-2 mb-3">
                        {p.description_en}
                      </p>
                      <div className="flex items-center space-x-1 text-amber-500 text-xs">
                        {[1, 2, 3, 4, 5].map((s) => (
                          <Star key={s} className="w-3.5 h-3.5 fill-current" />
                        ))}
                        <span className="text-stone-400 text-[11px] ml-1">(5.0)</span>
                      </div>
                    </div>
                  </div>

                  <div className="px-5 pb-5 pt-3 border-t border-stone-100 flex items-center justify-between">
                    <div>
                      <span className="text-[10px] uppercase text-stone-400 font-semibold block">Fair Price</span>
                      <span className="text-lg font-bold text-stone-900">
                        ₹{p.price.toLocaleString("en-IN")}
                      </span>
                    </div>
                    <button
                      onClick={(e) => handleAddToCart(e, p)}
                      className={`p-2.5 rounded-xl transition-all flex items-center space-x-1.5 text-xs font-semibold ${
                        addedId === p.id
                          ? "bg-emerald-600 text-white"
                          : "bg-[#C85A32] text-white hover:bg-[#B34D28] shadow-sm"
                      }`}
                    >
                      {addedId === p.id ? (
                        <>
                          <Check className="w-4 h-4" />
                          <span>Added</span>
                        </>
                      ) : (
                        <>
                          <ShoppingCart className="w-4 h-4" />
                          <span>Add</span>
                        </>
                      )}
                    </button>
                  </div>
                </Link>
              );
            })}
          </div>
        </div>
      </div>
    </div>
  );
}
