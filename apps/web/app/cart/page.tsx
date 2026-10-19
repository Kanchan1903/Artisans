"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import {
  Trash2,
  Plus,
  Minus,
  ShoppingBag,
  ArrowRight,
  ShieldCheck,
  Truck,
  Sparkles,
} from "lucide-react";
import { useCart } from "@/lib/cart-context";
import { useLanguage } from "@/lib/language-context";

export default function CartPage() {
  const router = useRouter();
  const { items, removeFromCart, updateQuantity, clearCart, totalPrice, totalItems } = useCart();
  const { t } = useLanguage();

  if (items.length === 0) {
    return (
      <div className="min-h-screen bg-[#FAF7F2] py-16 px-4 sm:px-6 lg:px-8 flex items-center justify-center">
        <div className="max-w-md w-full bg-white rounded-3xl p-8 sm:p-10 border border-stone-200/80 shadow-sm text-center">
          <div className="w-20 h-20 bg-[#FAF7F2] rounded-full flex items-center justify-center mx-auto mb-4 text-[#C85A32]">
            <ShoppingBag className="w-10 h-10" />
          </div>
          <h2 className="font-serif text-2xl font-bold text-stone-900 mb-2">
            {t("emptyCart", "Your Cart is Empty")}
          </h2>
          <p className="text-stone-600 text-sm mb-6">
            {t("emptyCartDesc", "Discover authentic Indian handicrafts made directly by marginalized village artisans.")}
          </p>
          <Link
            href="/products"
            className="inline-flex items-center justify-center w-full py-3.5 px-6 rounded-xl bg-[#C85A32] text-white font-semibold text-sm hover:bg-[#B34D28] transition-colors shadow-sm"
          >
            <span>{t("exploreCatalog", "Explore 2026 Collection")}</span>
            <ArrowRight className="w-4 h-4 ml-2" />
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[#FAF7F2] py-10 px-4 sm:px-6 lg:px-8">
      <div className="max-w-7xl mx-auto">
        <div className="flex items-center justify-between mb-8">
          <div>
            <h1 className="font-serif text-3xl font-bold text-stone-900">
              {t("shoppingCart", "Shopping Cart")} ({totalItems} {totalItems === 1 ? "item" : "items"})
            </h1>
            <p className="text-stone-500 text-sm mt-1">
              {t("heroSubtitle", "Every purchase directly supports an artisan’s livelihood and preserves cultural heritage.")}
            </p>
          </div>
          <button
            onClick={clearCart}
            className="text-xs text-rose-600 hover:underline flex items-center space-x-1"
          >
            <Trash2 className="w-3.5 h-3.5" />
            <span>{t("clearCart", "Clear Cart")}</span>
          </button>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-12 gap-8">
          {/* Cart Items List (8 cols) */}
          <div className="lg:col-span-8 space-y-4">
            {items.map(({ product, quantity }) => {
              const primaryImg =
                product.images?.[0]?.url ||
                "https://images.unsplash.com/photo-1582562124811-c09040d0a901?w=800";
              return (
                <div
                  key={product.id}
                  className="bg-white rounded-2xl p-4 sm:p-6 border border-stone-200/80 shadow-sm flex flex-col sm:flex-row items-center gap-4 sm:gap-6"
                >
                  <img
                    src={primaryImg}
                    alt={product.title_en}
                    className="w-24 h-24 sm:w-28 sm:h-28 rounded-xl object-cover bg-stone-100 flex-shrink-0"
                  />
                  <div className="flex-1 text-center sm:text-left">
                    <span className="text-[11px] font-semibold text-[#2C3E6B]">
                      {product.artisan?.craft_type || "Handicraft"}
                    </span>
                    <h3 className="font-serif font-bold text-stone-900 text-base sm:text-lg mb-1">
                      <Link href={`/products/${product.id}`} className="hover:text-[#C85A32]">
                        {product.title_en}
                      </Link>
                    </h3>
                    <p className="text-xs text-stone-500 mb-2">
                      {t("byArtisan", "By")}: <span className="font-medium text-stone-700">{product.artisan?.name}</span> ({product.artisan?.village}, {product.artisan?.state})
                    </p>
                    <span className="text-sm font-bold text-stone-900">
                      ₹{product.price.toLocaleString("en-IN")} each
                    </span>
                  </div>

                  <div className="flex items-center gap-4">
                    {/* Quantity Selector */}
                    <div className="flex items-center border border-stone-200 rounded-lg overflow-hidden bg-stone-50">
                      <button
                        onClick={() => updateQuantity(product.id, quantity - 1)}
                        className="p-2 hover:bg-stone-200 text-stone-600 transition"
                      >
                        <Minus className="w-3.5 h-3.5" />
                      </button>
                      <span className="px-3 text-xs font-bold text-stone-900">{quantity}</span>
                      <button
                        onClick={() => updateQuantity(product.id, quantity + 1)}
                        className="p-2 hover:bg-stone-200 text-stone-600 transition"
                      >
                        <Plus className="w-3.5 h-3.5" />
                      </button>
                    </div>

                    <button
                      onClick={() => removeFromCart(product.id)}
                      className="p-2 text-stone-400 hover:text-red-500 transition"
                      title="Remove"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>
                </div>
              );
            })}
          </div>

          {/* Order Summary (4 cols) */}
          <div className="lg:col-span-4">
            <div className="bg-white rounded-3xl p-6 sm:p-8 border border-stone-200/80 shadow-sm sticky top-24 space-y-6">
              <h3 className="font-serif text-xl font-bold text-stone-900 border-b border-stone-100 pb-4">
                {t("orderSummary", "Order Summary")}
              </h3>

              <div className="space-y-3 text-sm">
                <div className="flex justify-between text-stone-600">
                  <span>Subtotal</span>
                  <span className="font-semibold text-stone-800">
                    ₹{totalPrice.toLocaleString("en-IN")}
                  </span>
                </div>
                <div className="flex justify-between text-stone-600">
                  <span>Direct Artisan Delivery</span>
                  <span className="font-semibold text-emerald-600">FREE</span>
                </div>
                <div className="flex justify-between text-stone-600">
                  <span>{t("fairWageGuarantee", "Fair Wage Guaranteed")}</span>
                  <span className="font-semibold text-emerald-600">Included</span>
                </div>

                <div className="pt-3 border-t border-stone-200 flex justify-between items-baseline">
                  <span className="font-serif font-bold text-stone-900 text-lg">Total Amount</span>
                  <span className="text-2xl font-extrabold text-stone-900">
                    ₹{totalPrice.toLocaleString("en-IN")}
                  </span>
                </div>
              </div>

              <button
                onClick={() => router.push("/checkout")}
                className="w-full py-4 rounded-xl bg-[#C85A32] text-white font-semibold text-sm hover:bg-[#B34D28] transition-colors flex items-center justify-center space-x-2 shadow-sm"
              >
                <span>{t("proceedToCheckout", "Proceed to Secure Checkout")}</span>
                <ArrowRight className="w-4 h-4" />
              </button>

              <div className="space-y-3 pt-2 border-t border-stone-100 text-xs text-stone-500">
                <div className="flex items-center space-x-2">
                  <ShieldCheck className="w-4 h-4 text-emerald-600 flex-shrink-0" />
                  <span>100% Secure Checkout with Razorpay / UPI</span>
                </div>
                <div className="flex items-center space-x-2">
                  <Truck className="w-4 h-4 text-stone-600 flex-shrink-0" />
                  <span>Tracked Pan-India Delivery via India Post & Speed Post</span>
                </div>
                <div className="flex items-center space-x-2">
                  <Sparkles className="w-4 h-4 text-amber-500 flex-shrink-0" />
                  <span>{t("directArtisanImpact", "Direct Artisan Impact")}</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
