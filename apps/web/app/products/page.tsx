"use client";

import { useEffect, useState, useMemo, useCallback, Suspense } from "react";
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import {
  Filter, Search, SlidersHorizontal, Sparkles, MapPin,
  ShoppingCart, Check, Star, ArrowUpDown, RefreshCw, Package,
} from "lucide-react";
import { fetchProducts, fetchCategories, Product, Category } from "@/lib/api";
import { useCart } from "@/lib/cart-context";

// ─── State: no SAMPLE_PRODUCTS ever used here ─────────────────────────────────

type LoadState = "loading" | "ready" | "error";

function ProductsContent() {
  const searchParams = useSearchParams();
  const initialCategory = searchParams.get("category") || searchParams.get("category_id") || "";
  const initialSearch = searchParams.get("q") || searchParams.get("search") || "";

  const [products, setProducts] = useState<Product[]>([]);
  const [totalFromApi, setTotalFromApi] = useState<number>(0);
  const [categories, setCategories] = useState<Category[]>([]);
  const [loadState, setLoadState] = useState<LoadState>("loading");
  const [errorMsg, setErrorMsg] = useState("");

  // Filters
  const [selectedCategory, setSelectedCategory] = useState<string>(initialCategory);
  const [selectedState, setSelectedState] = useState<string>("all");
  const [priceRange, setPriceRange] = useState<number>(10000);
  const [searchQuery, setSearchQuery] = useState<string>(initialSearch);
  const [sortBy, setSortBy] = useState<string>("newest");
  const [mobileFilterOpen, setMobileFilterOpen] = useState(false);
  const [page, setPage] = useState(1);
  const PAGE_SIZE = 20;

  const { addToCart } = useCart();
  const [addedId, setAddedId] = useState<number | null>(null);

  // Fetch real products from backend
  const loadData = useCallback(async (reset = true) => {
    if (reset) setLoadState("loading");
    setErrorMsg("");

    try {
      const catId = categories.find((c) => c.slug === selectedCategory)?.id
        ?? (selectedCategory && !isNaN(Number(selectedCategory)) ? Number(selectedCategory) : undefined);

      const [prodData, catData] = await Promise.all([
        fetchProducts({
          category_id: catId,
          state: selectedState !== "all" ? selectedState : undefined,
          max_price: priceRange < 10000 ? priceRange : undefined,
          search: searchQuery.trim() || undefined,
          page: reset ? 1 : page,
          size: PAGE_SIZE,
        }),
        categories.length === 0 ? fetchCategories() : Promise.resolve(categories),
      ]);

      // Deduplicate by real product ID (in case API ever returns duplicates)
      const seen = new Set<number>();
      const deduped = prodData.items.filter((p) => {
        if (seen.has(p.id)) return false;
        seen.add(p.id);
        return true;
      });

      if (reset) {
        setPage(1);
        setProducts(deduped);
      } else {
        setProducts((prev) => {
          const combined = [...prev, ...deduped];
          const dedupedAll = new Map<number, Product>();
          combined.forEach((p) => dedupedAll.set(p.id, p));
          return Array.from(dedupedAll.values());
        });
      }

      setTotalFromApi(prodData.total);
      if (categories.length === 0) setCategories(catData);
      setLoadState("ready");
    } catch (err: any) {
      setErrorMsg(err.message || "Could not load products. Is the API running?");
      setLoadState("error");
      // Never fall back to SAMPLE_PRODUCTS
    }
  }, [selectedCategory, selectedState, priceRange, searchQuery, categories, page]);

  useEffect(() => { loadData(true); }, [selectedCategory, selectedState, priceRange]);
  useEffect(() => {
    const t = setTimeout(() => loadData(true), 350); // debounce search
    return () => clearTimeout(t);
  }, [searchQuery]);
  useEffect(() => { loadData(true); }, []); // initial load

  // Client-side sort only (server does filter)
  const displayedProducts = useMemo(() => {
    const sorted = [...products];
    if (sortBy === "price-low") return sorted.sort((a, b) => a.price - b.price);
    if (sortBy === "price-high") return sorted.sort((a, b) => b.price - a.price);
    if (sortBy === "newest") return sorted.sort((a, b) => b.id - a.id);
    return sorted;
  }, [products, sortBy]);

  const states = useMemo(() => {
    const set = new Set<string>();
    products.forEach((p) => { if (p.artisan?.state) set.add(p.artisan.state); });
    return Array.from(set).sort();
  }, [products]);

  const hasMore = totalFromApi > products.length;

  const handleAddToCart = (e: React.MouseEvent, p: Product) => {
    e.preventDefault();
    e.stopPropagation();
    addToCart(p, 1);
    setAddedId(p.id);
    setTimeout(() => setAddedId(null), 1500);
  };

  const resetFilters = () => {
    setSelectedCategory("");
    setSelectedState("all");
    setPriceRange(10000);
    setSearchQuery("");
  };

  return (
    <div className="min-h-screen bg-[#FAF7F2] py-8 px-4 sm:px-6 lg:px-8">
      <div className="max-w-7xl mx-auto">
        {/* Header */}
        <div className="mb-8">
          <div className="flex items-center space-x-2 text-xs text-stone-500 mb-2">
            <Link href="/" className="hover:text-[#C85A32]">Home</Link>
            <span>/</span>
            <span className="text-stone-800 font-medium">Craft Catalog</span>
          </div>
          <div className="flex flex-col md:flex-row md:items-end justify-between gap-4">
            <div>
              <h1 className="font-serif text-3xl sm:text-4xl font-bold text-stone-900">
                Handcrafted Treasures of Bharat
              </h1>
              <p className="text-stone-600 mt-1 text-sm sm:text-base">
                Directly sourced from indigenous artisans, verified for GI heritage and fair wages.
              </p>
            </div>
            <div className="flex items-center gap-3">
              <button
                onClick={() => setMobileFilterOpen(!mobileFilterOpen)}
                className="md:hidden flex items-center gap-2 px-4 py-2.5 bg-white border border-stone-200 rounded-lg text-sm font-medium text-stone-700 shadow-sm"
              >
                <SlidersHorizontal className="w-4 h-4 text-[#C85A32]" />
                Filters
              </button>
              <div className="relative">
                <select
                  value={sortBy}
                  onChange={(e) => setSortBy(e.target.value)}
                  className="appearance-none bg-white border border-stone-200 rounded-lg px-4 py-2.5 pr-8 text-sm font-medium text-stone-700 shadow-sm focus:outline-none focus:ring-2 focus:ring-[#C85A32]"
                >
                  <option value="newest">Recently Published</option>
                  <option value="price-low">Price: Low to High</option>
                  <option value="price-high">Price: High to Low</option>
                </select>
                <ArrowUpDown className="w-4 h-4 text-stone-400 absolute right-2.5 top-3.5 pointer-events-none" />
              </div>
            </div>
          </div>
        </div>

        {/* Search */}
        <div className="relative mb-8">
          <Search className="w-5 h-5 text-stone-400 absolute left-4 top-3.5" />
          <input
            type="text"
            placeholder="Search by craft technique, Warli, Madhubani, Terracotta, or artisan name..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pl-12 pr-4 py-3 bg-white rounded-xl border border-stone-200 shadow-sm text-stone-800 placeholder-stone-400 focus:outline-none focus:ring-2 focus:ring-[#C85A32] focus:border-transparent text-sm"
          />
        </div>

        <div className="grid grid-cols-1 md:grid-cols-4 gap-8">
          {/* Sidebar */}
          <aside className={`${mobileFilterOpen ? "block" : "hidden"} md:block md:col-span-1 bg-white p-6 rounded-2xl border border-stone-200/80 shadow-sm space-y-6 h-fit sticky top-24`}>
            <div className="flex items-center justify-between border-b border-stone-100 pb-4">
              <div className="flex items-center space-x-2">
                <Filter className="w-4 h-4 text-[#C85A32]" />
                <h2 className="font-semibold text-stone-900 text-base">Filter Craft</h2>
              </div>
              <button onClick={resetFilters} className="text-xs text-[#C85A32] hover:underline font-medium">
                Reset All
              </button>
            </div>

            {/* Category */}
            <div>
              <label className="block text-xs font-bold uppercase tracking-wider text-stone-500 mb-3">
                Craft Category
              </label>
              <div className="space-y-2">
                <button
                  onClick={() => setSelectedCategory("")}
                  className={`w-full text-left px-3 py-2 rounded-lg text-sm transition-colors ${
                    !selectedCategory ? "bg-[#C85A32]/10 text-[#C85A32] font-semibold" : "text-stone-600 hover:bg-stone-50"
                  }`}
                >
                  All Categories
                </button>
                {categories.map((c) => (
                  <button
                    key={c.id}
                    onClick={() => setSelectedCategory(c.slug)}
                    className={`w-full text-left px-3 py-2 rounded-lg text-sm transition-colors ${
                      selectedCategory === c.slug || selectedCategory === String(c.id)
                        ? "bg-[#C85A32]/10 text-[#C85A32] font-semibold"
                        : "text-stone-600 hover:bg-stone-50"
                    }`}
                  >
                    {c.name}
                  </button>
                ))}
              </div>
            </div>

            {/* State */}
            <div>
              <label className="block text-xs font-bold uppercase tracking-wider text-stone-500 mb-3">
                Origin State
              </label>
              <select
                value={selectedState}
                onChange={(e) => setSelectedState(e.target.value)}
                className="w-full bg-stone-50 border border-stone-200 rounded-lg px-3 py-2 text-sm text-stone-700 focus:outline-none focus:ring-2 focus:ring-[#C85A32]"
              >
                <option value="all">All States</option>
                {states.map((s) => <option key={s} value={s}>{s}</option>)}
              </select>
            </div>

            {/* Price */}
            <div>
              <div className="flex justify-between items-center mb-2">
                <label className="text-xs font-bold uppercase tracking-wider text-stone-500">Max Price</label>
                <span className="text-sm font-semibold text-stone-900">
                  ₹{priceRange >= 10000 ? "Any" : priceRange.toLocaleString("en-IN")}
                </span>
              </div>
              <input
                type="range" min="300" max="10000" step="100"
                value={priceRange}
                onChange={(e) => setPriceRange(Number(e.target.value))}
                className="w-full accent-[#C85A32] cursor-pointer"
              />
              <div className="flex justify-between text-xs text-stone-400 mt-1">
                <span>₹300</span><span>Any</span>
              </div>
            </div>

            <div className="p-3 bg-amber-50/60 rounded-xl border border-amber-200/60">
              <div className="flex items-center space-x-2 text-amber-800 text-xs font-medium mb-1">
                <Sparkles className="w-3.5 h-3.5 text-amber-600" />
                <span>AI Digitized Direct From Villages</span>
              </div>
              <p className="text-[11px] text-amber-700 leading-relaxed">
                Every listing is created via voice cataloging in the artisan's native dialect.
              </p>
            </div>
          </aside>

          {/* Product Grid */}
          <main className="md:col-span-3">
            {/* Status bar */}
            <div className="mb-4 text-xs text-stone-500 flex items-center justify-between">
              {loadState === "ready" && (
                <span>
                  Showing <strong className="text-stone-800">{displayedProducts.length}</strong> of{" "}
                  <strong className="text-stone-800">{totalFromApi}</strong> handcrafted products
                </span>
              )}
              {loadState === "loading" && <span className="text-stone-400">Loading products from artisans...</span>}
              {loadState === "error" && <span className="text-red-500">Failed to load — see error below</span>}
            </div>

            {/* Loading */}
            {loadState === "loading" && (
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
                {[1, 2, 3, 4, 5, 6].map((i) => (
                  <div key={i} className="animate-pulse bg-white rounded-2xl p-4 border border-stone-200/60">
                    <div className="bg-stone-200 h-64 rounded-xl mb-4" />
                    <div className="h-4 bg-stone-200 rounded w-3/4 mb-2" />
                    <div className="h-3 bg-stone-200 rounded w-1/2 mb-4" />
                    <div className="h-6 bg-stone-200 rounded w-1/3" />
                  </div>
                ))}
              </div>
            )}

            {/* Error */}
            {loadState === "error" && (
              <div className="bg-white rounded-2xl border border-red-200 p-12 text-center">
                <div className="w-16 h-16 bg-red-50 rounded-full flex items-center justify-center mx-auto mb-4">
                  <RefreshCw className="w-8 h-8 text-red-400" />
                </div>
                <h3 className="font-serif text-xl font-bold text-stone-800 mb-2">
                  Could not load products
                </h3>
                <p className="text-stone-500 text-sm max-w-md mx-auto mb-6">{errorMsg}</p>
                <button
                  onClick={() => loadData(true)}
                  className="px-6 py-2.5 bg-[#C85A32] text-white rounded-xl text-sm font-medium hover:bg-[#B34D28] transition-colors shadow-sm flex items-center gap-2 mx-auto"
                >
                  <RefreshCw className="w-4 h-4" /> Retry
                </button>
              </div>
            )}

            {/* Empty state */}
            {loadState === "ready" && displayedProducts.length === 0 && (
              <div className="bg-white rounded-2xl border border-stone-200 p-12 text-center">
                <div className="w-20 h-20 bg-[#FAF7F2] rounded-full flex items-center justify-center mx-auto mb-4 text-[#C85A32]">
                  <Package className="w-10 h-10" />
                </div>
                <h3 className="font-serif text-xl font-bold text-stone-800 mb-2">
                  {searchQuery || selectedCategory ? "No crafts match your filters" : "No products available yet"}
                </h3>
                <p className="text-stone-500 text-sm max-w-md mx-auto mb-6">
                  {searchQuery || selectedCategory
                    ? "Try adjusting your search or filters."
                    : "No products have been published by artisans yet. Check back soon!"}
                </p>
                {(searchQuery || selectedCategory || selectedState !== "all") && (
                  <button
                    onClick={resetFilters}
                    className="px-6 py-2.5 bg-[#C85A32] text-white rounded-xl text-sm font-medium hover:bg-[#B34D28] transition-colors shadow-sm"
                  >
                    Clear All Filters
                  </button>
                )}
              </div>
            )}

            {/* Products */}
            {loadState === "ready" && displayedProducts.length > 0 && (
              <>
                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
                  {displayedProducts.map((p) => {
                    const primaryImg = p.images?.find((i) => i.is_primary)?.url
                      ?? p.images?.[0]?.url
                      ?? "https://images.unsplash.com/photo-1582562124811-c09040d0a901?w=800";
                    const inStock = p.stock > 0;

                    return (
                      <Link
                        key={`product-${p.id}`}
                        href={`/products/${p.id}`}
                        className="group bg-white rounded-2xl overflow-hidden border border-stone-200/80 shadow-sm hover:shadow-md transition-all flex flex-col justify-between"
                      >
                        <div>
                          <div className="relative aspect-square w-full bg-stone-100 overflow-hidden">
                            <img
                              src={primaryImg}
                              alt={p.title_en}
                              className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
                              onError={(e) => {
                                (e.target as HTMLImageElement).src = "https://images.unsplash.com/photo-1582562124811-c09040d0a901?w=800";
                              }}
                            />
                            {p.ai_generated && (
                              <span className="absolute top-3 left-3 inline-flex items-center space-x-1 bg-white/95 backdrop-blur-sm px-2.5 py-1 rounded-full text-[11px] font-medium text-stone-800 shadow-sm">
                                <Sparkles className="w-3 h-3 text-[#E09F3E]" />
                                <span>AI Studio</span>
                              </span>
                            )}
                            {!inStock && (
                              <span className="absolute top-3 right-3 px-2 py-0.5 bg-stone-800/80 text-white text-[10px] font-bold rounded-full">
                                Out of Stock
                              </span>
                            )}
                            <span className="absolute bottom-3 left-3 inline-flex items-center space-x-1 bg-stone-900/75 backdrop-blur-sm px-2 py-0.5 rounded text-[10px] text-white font-medium">
                              <MapPin className="w-3 h-3 text-amber-400" />
                              <span>{p.artisan?.state || "India"}</span>
                            </span>
                          </div>

                          <div className="p-4 sm:p-5">
                            <p className="text-xs font-semibold text-[#2C3E6B] mb-1">
                              {p.artisan?.craft_type || p.category?.name || "Heritage Craft"}
                            </p>
                            <h3 className="font-serif font-bold text-stone-900 group-hover:text-[#C85A32] transition-colors line-clamp-2 text-base mb-1">
                              {p.title_en}
                            </h3>
                            <p className="text-xs text-stone-500">
                              By <span className="font-medium text-stone-700">{p.artisan?.name || "Master Artisan"}</span>
                            </p>
                            {inStock && p.stock <= 5 && (
                              <p className="text-[11px] text-amber-600 font-semibold mt-1">
                                Only {p.stock} left!
                              </p>
                            )}
                          </div>
                        </div>

                        <div className="px-4 sm:px-5 pb-5 pt-3 border-t border-stone-100 flex items-center justify-between">
                          <div>
                            <span className="text-[10px] uppercase text-stone-400 font-semibold block">Direct Fair Price</span>
                            <span className="text-lg font-bold text-stone-900">
                              ₹{p.price.toLocaleString("en-IN")}
                            </span>
                          </div>
                          <button
                            onClick={(e) => handleAddToCart(e, p)}
                            disabled={!inStock}
                            className={`p-2.5 rounded-xl transition-all flex items-center space-x-1.5 text-xs font-semibold ${
                              !inStock
                                ? "bg-stone-200 text-stone-400 cursor-not-allowed"
                                : addedId === p.id
                                ? "bg-emerald-600 text-white"
                                : "bg-[#C85A32] text-white hover:bg-[#B34D28] shadow-sm"
                            }`}
                          >
                            {addedId === p.id ? (
                              <><Check className="w-4 h-4" /><span>Added</span></>
                            ) : (
                              <><ShoppingCart className="w-4 h-4" /><span>Add</span></>
                            )}
                          </button>
                        </div>
                      </Link>
                    );
                  })}
                </div>

                {/* Load More */}
                {hasMore && (
                  <div className="mt-10 text-center">
                    <button
                      onClick={() => {
                        setPage((p) => p + 1);
                        loadData(false);
                      }}
                      className="px-8 py-3 bg-white border border-stone-300 text-stone-700 font-semibold rounded-xl hover:bg-stone-50 transition shadow-sm"
                    >
                      Load More ({totalFromApi - products.length} remaining)
                    </button>
                  </div>
                )}
              </>
            )}
          </main>
        </div>
      </div>
    </div>
  );
}

export default function ProductsPage() {
  return (
    <Suspense fallback={
      <div className="min-h-screen bg-[#FAF7F2] flex items-center justify-center">
        <div className="animate-spin rounded-full h-10 w-10 border-4 border-[#C85A32] border-t-transparent" />
      </div>
    }>
      <ProductsContent />
    </Suspense>
  );
}
