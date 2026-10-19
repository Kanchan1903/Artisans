/**
 * Shared UI Components:
 * - ProductCardSkeleton
 * - ErrorState (with retry)
 * - EmptyState
 * - Toast notification system
 * - ProductCard (real data)
 */
"use client";

import React, { useEffect, useState, useCallback } from "react";
import Link from "next/link";
import { ShoppingBag, Heart, Star, AlertCircle, RefreshCw, Package, Search, CheckCircle, XCircle, Info } from "lucide-react";
import { Product } from "@/lib/api";
import { useCart } from "@/lib/cart-context";

// ─── Product Card Skeleton ─────────────────────────────────────────────────────

export function ProductCardSkeleton() {
  return (
    <div className="bg-white rounded-2xl overflow-hidden border border-stone-100 animate-pulse">
      <div className="aspect-square bg-stone-200" />
      <div className="p-4 space-y-2">
        <div className="h-3 bg-stone-200 rounded w-1/3" />
        <div className="h-4 bg-stone-200 rounded w-3/4" />
        <div className="h-3 bg-stone-200 rounded w-1/2" />
        <div className="flex justify-between items-center pt-2">
          <div className="h-5 bg-stone-200 rounded w-1/4" />
          <div className="h-8 w-8 bg-stone-200 rounded-full" />
        </div>
      </div>
    </div>
  );
}

export function ProductGridSkeleton({ count = 8 }: { count?: number }) {
  return (
    <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4 md:gap-6">
      {Array.from({ length: count }).map((_, i) => (
        <ProductCardSkeleton key={i} />
      ))}
    </div>
  );
}

// ─── Error State ──────────────────────────────────────────────────────────────

export function ErrorState({
  message,
  onRetry,
  compact = false,
}: {
  message: string;
  onRetry?: () => void;
  compact?: boolean;
}) {
  if (compact) {
    return (
      <div className="flex items-center gap-3 px-4 py-3 bg-red-50 border border-red-200 rounded-xl text-sm text-red-700">
        <AlertCircle className="w-4 h-4 flex-shrink-0" />
        <span className="flex-1">{message}</span>
        {onRetry && (
          <button
            onClick={onRetry}
            className="flex items-center gap-1 text-xs font-semibold text-red-600 hover:text-red-800 transition"
          >
            <RefreshCw className="w-3 h-3" /> Retry
          </button>
        )}
      </div>
    );
  }

  return (
    <div className="flex flex-col items-center justify-center py-20 px-4 text-center">
      <div className="w-16 h-16 rounded-2xl bg-red-100 flex items-center justify-center mb-4">
        <AlertCircle className="w-8 h-8 text-red-500" />
      </div>
      <h3 className="font-serif text-xl font-bold text-stone-800 mb-2">Something went wrong</h3>
      <p className="text-stone-500 text-sm max-w-md mb-6">{message}</p>
      {onRetry && (
        <button
          onClick={onRetry}
          className="flex items-center gap-2 px-6 py-3 bg-[#C85A32] text-white rounded-xl text-sm font-bold hover:bg-[#B34D28] transition"
        >
          <RefreshCw className="w-4 h-4" />
          Try Again
        </button>
      )}
    </div>
  );
}

// ─── Empty State ──────────────────────────────────────────────────────────────

export function EmptyState({
  icon: Icon = Package,
  title,
  description,
  action,
}: {
  icon?: React.ElementType;
  title: string;
  description?: string;
  action?: { label: string; href?: string; onClick?: () => void };
}) {
  return (
    <div className="flex flex-col items-center justify-center py-20 px-4 text-center">
      <div className="w-20 h-20 rounded-3xl bg-stone-100 flex items-center justify-center mb-6">
        <Icon className="w-10 h-10 text-stone-400" />
      </div>
      <h3 className="font-serif text-xl font-bold text-stone-800 mb-2">{title}</h3>
      {description && <p className="text-stone-500 text-sm max-w-md mb-6">{description}</p>}
      {action && (
        action.href ? (
          <Link
            href={action.href}
            className="px-6 py-3 bg-[#C85A32] text-white rounded-xl text-sm font-bold hover:bg-[#B34D28] transition"
          >
            {action.label}
          </Link>
        ) : (
          <button
            onClick={action.onClick}
            className="px-6 py-3 bg-[#C85A32] text-white rounded-xl text-sm font-bold hover:bg-[#B34D28] transition"
          >
            {action.label}
          </button>
        )
      )}
    </div>
  );
}

// ─── Toast System ─────────────────────────────────────────────────────────────

type ToastType = "success" | "error" | "info";

interface ToastMessage {
  id: string;
  type: ToastType;
  message: string;
}

const toastListeners: Array<(toast: ToastMessage) => void> = [];

export const toast = {
  success: (message: string) => emit({ type: "success", message }),
  error: (message: string) => emit({ type: "error", message }),
  info: (message: string) => emit({ type: "info", message }),
};

function emit(t: Omit<ToastMessage, "id">) {
  const toast: ToastMessage = { ...t, id: Math.random().toString(36).slice(2) };
  toastListeners.forEach((fn) => fn(toast));
}

const TOAST_ICONS: Record<ToastType, React.ReactNode> = {
  success: <CheckCircle className="w-4 h-4 text-emerald-500" />,
  error: <XCircle className="w-4 h-4 text-red-500" />,
  info: <Info className="w-4 h-4 text-blue-500" />,
};

const TOAST_BG: Record<ToastType, string> = {
  success: "bg-white border-emerald-200",
  error: "bg-white border-red-200",
  info: "bg-white border-blue-200",
};

export function ToastContainer() {
  const [toasts, setToasts] = useState<ToastMessage[]>([]);

  useEffect(() => {
    const listener = (t: ToastMessage) => {
      setToasts((prev) => [...prev, t]);
      setTimeout(() => {
        setToasts((prev) => prev.filter((x) => x.id !== t.id));
      }, 4000);
    };
    toastListeners.push(listener);
    return () => {
      const idx = toastListeners.indexOf(listener);
      if (idx !== -1) toastListeners.splice(idx, 1);
    };
  }, []);

  if (toasts.length === 0) return null;

  return (
    <div className="fixed bottom-6 right-6 z-[9999] flex flex-col gap-2 max-w-sm w-full pointer-events-none">
      {toasts.map((t) => (
        <div
          key={t.id}
          className={`flex items-start gap-3 px-4 py-3 rounded-xl border shadow-lg text-sm text-stone-800 font-medium pointer-events-auto animate-slide-up ${TOAST_BG[t.type]}`}
        >
          <span className="flex-shrink-0 mt-0.5">{TOAST_ICONS[t.type]}</span>
          <span>{t.message}</span>
        </div>
      ))}
    </div>
  );
}

// ─── Product Card ─────────────────────────────────────────────────────────────

export function ProductCard({ product }: { product: Product }) {
  const { addToCart } = useCart();
  const [adding, setAdding] = useState(false);
  const [wishlisted, setWishlisted] = useState(false);

  const primaryImage = product.images?.find((i) => i.is_primary)?.url
    ?? product.images?.[0]?.url
    ?? "/placeholder-craft.jpg";

  const artisanName = product.artisan?.name;
  const location = product.artisan
    ? [product.artisan.village, product.artisan.state].filter(Boolean).join(", ")
    : null;

  const inStock = product.stock > 0;

  const handleAddToCart = (e: React.MouseEvent) => {
    e.preventDefault();
    e.stopPropagation();
    if (!inStock || adding) return;
    setAdding(true);
    addToCart(product, 1);
    toast.success(`"${product.title_en.slice(0, 30)}…" added to cart`);
    setTimeout(() => setAdding(false), 1000);
  };

  return (
    <Link href={`/products/${product.id}`} className="group block">
      <div className="bg-white rounded-2xl overflow-hidden border border-stone-100 shadow-sm hover:shadow-lg hover:-translate-y-0.5 transition-all duration-200">
        {/* Image */}
        <div className="relative aspect-square overflow-hidden bg-stone-50">
          <img
            src={primaryImage}
            alt={product.title_en}
            className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
            onError={(e) => {
              (e.target as HTMLImageElement).src = "https://images.unsplash.com/photo-1582562124811-c09040d0a901?w=400";
            }}
          />
          {/* Badges */}
          <div className="absolute top-2 left-2 flex flex-col gap-1">
            {!inStock && (
              <span className="px-2 py-0.5 bg-stone-800/80 text-white text-[10px] font-bold rounded-full">
                Out of Stock
              </span>
            )}
            {product.ai_generated && (
              <span className="px-2 py-0.5 bg-[#2C3E6B]/80 text-white text-[10px] font-bold rounded-full">
                ✦ AI Crafted
              </span>
            )}
          </div>
          {/* Wishlist */}
          <button
            onClick={(e) => { e.preventDefault(); e.stopPropagation(); setWishlisted((w) => !w); }}
            className={`absolute top-2 right-2 w-7 h-7 rounded-full flex items-center justify-center shadow transition ${
              wishlisted ? "bg-red-500 text-white" : "bg-white/90 text-stone-400 hover:text-red-400"
            }`}
          >
            <Heart className={`w-3.5 h-3.5 ${wishlisted ? "fill-current" : ""}`} />
          </button>
        </div>

        {/* Info */}
        <div className="p-3">
          {artisanName && (
            <p className="text-[10px] font-semibold text-[#C85A32] uppercase tracking-wide truncate mb-0.5">
              {artisanName} {location ? `· ${location}` : ""}
            </p>
          )}
          <h3 className="text-sm font-bold text-stone-900 leading-snug line-clamp-2 mb-1">
            {product.title_en}
          </h3>
          {product.material && (
            <p className="text-[10px] text-stone-400 truncate">{product.material}</p>
          )}
          <div className="flex items-center justify-between mt-2">
            <span className="font-black text-[#262220] text-base">
              ₹{product.price.toLocaleString("en-IN")}
            </span>
            <button
              onClick={handleAddToCart}
              disabled={!inStock || adding}
              className={`w-8 h-8 rounded-full flex items-center justify-center transition shadow-sm ${
                inStock
                  ? "bg-[#C85A32] text-white hover:bg-[#B34D28]"
                  : "bg-stone-200 text-stone-400 cursor-not-allowed"
              }`}
              title={inStock ? "Add to cart" : "Out of stock"}
            >
              <ShoppingBag className="w-3.5 h-3.5" />
            </button>
          </div>
          {inStock && product.stock <= 5 && (
            <p className="text-[10px] text-amber-600 font-semibold mt-1">
              Only {product.stock} left!
            </p>
          )}
        </div>
      </div>
    </Link>
  );
}

// ─── Star Rating Display ──────────────────────────────────────────────────────

export function StarRating({ rating, max = 5, size = "sm" }: { rating: number; max?: number; size?: "sm" | "md" }) {
  const px = size === "sm" ? "w-3 h-3" : "w-4 h-4";
  return (
    <div className="flex items-center gap-0.5">
      {Array.from({ length: max }).map((_, i) => (
        <Star
          key={i}
          className={`${px} ${i < Math.round(rating) ? "text-amber-400 fill-amber-400" : "text-stone-200 fill-stone-200"}`}
        />
      ))}
    </div>
  );
}
