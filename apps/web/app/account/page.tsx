"use client";

import { useState, useEffect } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import {
  User,
  Package,
  MapPin,
  Heart,
  ShieldCheck,
  Sparkles,
  ChevronRight,
  ExternalLink,
  Phone,
  Mail,
  ShoppingBag,
  LogOut,
  RefreshCw,
  Trash2,
} from "lucide-react";
import { useAuth } from "@/lib/auth-context";
import { fetchMyOrders, fetchMyWishlist, toggleWishlist, Order, WishlistItem } from "@/lib/api";
import { useCart } from "@/lib/cart-context";

export default function AccountPage() {
  const { user, isLoggedIn, isArtisan, logout, isLoading, token } = useAuth();
  const { addToCart } = useCart();
  const router = useRouter();

  const [activeTab, setActiveTab] = useState<"orders" | "addresses" | "wishlist">("orders");
  const [orders, setOrders] = useState<Order[]>([]);
  const [wishlist, setWishlist] = useState<WishlistItem[]>([]);
  const [ordersLoading, setOrdersLoading] = useState(true);
  const [wishlistLoading, setWishlistLoading] = useState(false);
  const [ordersError, setOrdersError] = useState("");

  useEffect(() => {
    if (!isLoading) {
      if (!isLoggedIn) {
        router.replace("/login?redirect=/account");
      }
    }
  }, [isLoading, isLoggedIn, router]);

  // Load real orders from backend
  useEffect(() => {
    if (!token) return;

    let mounted = true;
    async function loadOrders() {
      setOrdersLoading(true);
      setOrdersError("");
      try {
        const data = await fetchMyOrders(token!);
        if (mounted) setOrders(data);
      } catch (err: any) {
        if (mounted) setOrdersError(err.message || "Failed to load orders");
      } finally {
        if (mounted) setOrdersLoading(false);
      }
    }

    loadOrders();
    return () => {
      mounted = false;
    };
  }, [token]);

  // Load wishlist when tab is selected
  useEffect(() => {
    if (activeTab === "wishlist" && token) {
      let mounted = true;
      setWishlistLoading(true);
      fetchMyWishlist(token)
        .then((items) => {
          if (mounted) setWishlist(items);
        })
        .catch(() => {})
        .finally(() => {
          if (mounted) setWishlistLoading(false);
        });
      return () => {
        mounted = false;
      };
    }
  }, [activeTab, token]);

  if (isLoading || !isLoggedIn) {
    return (
      <div className="min-h-screen bg-[#FAF7F2] flex items-center justify-center">
        <div className="w-10 h-10 border-4 border-[#C85A32] border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  const handleLogout = () => {
    logout();
    router.replace("/login");
  };

  // Extract unique saved addresses from real orders
  const savedAddresses = orders
    .map((o) => o.shipping_address)
    .filter((addr): addr is NonNullable<typeof addr> => !!addr && !!addr.line1)
    .filter(
      (addr, index, self) =>
        index === self.findIndex((a) => a.line1 === addr.line1 && a.pincode === addr.pincode)
    );

  // Compute total direct impact from real orders
  const totalImpact = orders.reduce((sum, o) => sum + (o.total || 0), 0);

  const handleRemoveWishlist = async (productId: number) => {
    if (!token) return;
    try {
      await toggleWishlist(productId, token);
      setWishlist((prev) => prev.filter((item) => item.product_id !== productId));
    } catch (_) {}
  };

  return (
    <div className="min-h-screen bg-[#FAF7F2] py-10 px-4 sm:px-6 lg:px-8">
      <div className="max-w-6xl mx-auto space-y-8">
        {/* Header Breadcrumb */}
        <div className="flex items-center space-x-2 text-xs text-stone-500">
          <Link href="/" className="hover:text-[#C85A32]">
            Home
          </Link>
          <ChevronRight className="w-3 h-3 text-stone-400" />
          <span className="text-stone-800 font-medium">Buyer Account</span>
        </div>

        {/* Profile Card & Impact Summary */}
        <div className="bg-white rounded-3xl p-6 sm:p-8 border border-stone-200/80 shadow-sm flex flex-col md:flex-row items-center md:items-start justify-between gap-6">
          <div className="flex items-center space-x-5">
            <div className="w-20 h-20 rounded-2xl bg-[#C85A32]/10 border-2 border-[#C85A32] flex items-center justify-center text-[#C85A32] flex-shrink-0">
              <User className="w-10 h-10" />
            </div>
            <div>
              <div className="flex items-center space-x-2">
                <h1 className="font-serif text-2xl font-bold text-stone-900">
                  {user?.name || "Buyer"}
                </h1>
                <span className="px-2.5 py-0.5 rounded-full text-[11px] font-semibold bg-emerald-100 text-emerald-800 flex items-center gap-1">
                  <ShieldCheck className="w-3 h-3" />
                  Verified Buyer
                </span>
              </div>
              <div className="flex flex-wrap items-center gap-4 text-xs text-stone-500 mt-1.5">
                <span className="flex items-center gap-1">
                  <Phone className="w-3.5 h-3.5 text-[#C85A32]" />
                  {user?.phone || "+91 —"}
                </span>
                {user?.email && (
                  <span className="flex items-center gap-1">
                    <Mail className="w-3.5 h-3.5 text-[#2C3E6B]" />
                    {user.email}
                  </span>
                )}
                {savedAddresses.length > 0 && (
                  <span className="flex items-center gap-1">
                    <MapPin className="w-3.5 h-3.5 text-emerald-600" />
                    {savedAddresses[0].city}, {savedAddresses[0].state}
                  </span>
                )}
              </div>
            </div>
          </div>

          {/* Right side: dynamic impact + logout */}
          <div className="flex flex-col items-center md:items-end gap-3">
            <div className="bg-[#FAF7F2] p-4 rounded-2xl border border-stone-200 text-center md:text-right">
              <span className="text-[11px] uppercase tracking-wider text-stone-500 font-semibold block">
                Direct Artisan Impact
              </span>
              <span className="text-2xl font-extrabold text-[#C85A32]">
                ₹{totalImpact.toLocaleString("en-IN")}
              </span>
              <span className="text-[11px] text-stone-500 block">
                {orders.length > 0
                  ? `Transferred directly across ${orders.length} artisan order${orders.length > 1 ? "s" : ""}`
                  : "Start shopping to directly support rural artisan clusters"}
              </span>
            </div>
            <button
              id="account-logout-btn"
              onClick={handleLogout}
              className="flex items-center gap-1.5 text-xs font-semibold text-red-500 hover:text-red-700 transition"
            >
              <LogOut className="w-3.5 h-3.5" />
              Sign Out
            </button>
          </div>
        </div>

        {/* Tab Controls */}
        <div className="flex border-b border-stone-200 space-x-6 text-sm font-semibold">
          <button
            onClick={() => setActiveTab("orders")}
            className={`pb-3 transition-colors ${
              activeTab === "orders"
                ? "text-[#C85A32] border-b-2 border-[#C85A32]"
                : "text-stone-500 hover:text-stone-800"
            }`}
          >
            My Orders ({orders.length})
          </button>
          <button
            onClick={() => setActiveTab("addresses")}
            className={`pb-3 transition-colors ${
              activeTab === "addresses"
                ? "text-[#C85A32] border-b-2 border-[#C85A32]"
                : "text-stone-500 hover:text-stone-800"
            }`}
          >
            Saved Addresses ({savedAddresses.length})
          </button>
          <button
            onClick={() => setActiveTab("wishlist")}
            className={`pb-3 transition-colors ${
              activeTab === "wishlist"
                ? "text-[#C85A32] border-b-2 border-[#C85A32]"
                : "text-stone-500 hover:text-stone-800"
            }`}
          >
            Wishlist ({wishlist.length})
          </button>
        </div>

        {/* TAB 1: REAL ORDERS */}
        {activeTab === "orders" && (
          <div className="space-y-4">
            {ordersLoading ? (
              <div className="bg-white rounded-3xl p-12 text-center border border-stone-200/80">
                <div className="w-8 h-8 border-3 border-[#C85A32] border-t-transparent rounded-full animate-spin mx-auto mb-3" />
                <p className="text-xs text-stone-500">Loading your orders...</p>
              </div>
            ) : ordersError ? (
              <div className="bg-white rounded-3xl p-10 border border-red-200 text-center">
                <p className="text-sm text-red-600 mb-3">{ordersError}</p>
                <button
                  onClick={() => window.location.reload()}
                  className="px-4 py-2 bg-[#C85A32] text-white rounded-xl text-xs font-semibold hover:bg-[#B34D28]"
                >
                  Retry
                </button>
              </div>
            ) : orders.length === 0 ? (
              /* CLEAN EMPTY STATE - NEVER SHOWS HARDCODED ORDERS */
              <div className="bg-white rounded-3xl p-12 border border-stone-200/80 text-center max-w-md mx-auto">
                <div className="w-16 h-16 bg-[#FAF7F2] rounded-2xl flex items-center justify-center text-[#C85A32] mx-auto mb-4">
                  <Package className="w-8 h-8" />
                </div>
                <h3 className="font-serif text-lg font-bold text-stone-900 mb-1">
                  No orders placed yet
                </h3>
                <p className="text-stone-500 text-xs mb-6 leading-relaxed">
                  When you order authentic handcrafted items, your orders and real-time tracking will appear right here.
                </p>
                <Link
                  href="/products"
                  className="inline-flex items-center gap-2 px-6 py-2.5 rounded-xl bg-[#C85A32] text-white text-xs font-semibold hover:bg-[#B34D28] transition shadow-sm"
                >
                  <ShoppingBag className="w-4 h-4" />
                  <span>Explore Catalog</span>
                </Link>
              </div>
            ) : (
              orders.map((o) => (
                <div
                  key={o.id}
                  className="bg-white rounded-3xl p-6 border border-stone-200/80 shadow-sm space-y-4"
                >
                  <div className="flex flex-col sm:flex-row sm:items-center justify-between pb-4 border-b border-stone-100 gap-2">
                    <div>
                      <span className="text-xs font-mono font-bold text-stone-900 block">
                        Order #{o.id}
                      </span>
                      <span className="text-xs text-stone-500">
                        Placed on {new Date(o.created_at).toLocaleDateString("en-IN", { dateStyle: "long" })}
                      </span>
                    </div>
                    <div className="flex items-center space-x-3">
                      <span className="capitalize px-3 py-1 rounded-full text-xs font-bold bg-amber-50 text-amber-800 border border-amber-200">
                        Status: {o.status}
                      </span>
                      <Link
                        href={`/orders/${o.id}`}
                        className="px-4 py-1.5 rounded-xl bg-[#C85A32] text-white text-xs font-semibold hover:bg-[#B34D28] transition flex items-center space-x-1"
                      >
                        <span>Track Package</span>
                        <ExternalLink className="w-3.5 h-3.5" />
                      </Link>
                    </div>
                  </div>

                  {/* Line items from backend */}
                  <div className="divide-y divide-stone-100">
                    {o.items?.map((item, idx) => (
                      <div key={idx} className="py-3 flex items-center justify-between text-sm">
                        <div className="flex items-center space-x-4">
                          <img
                            src={
                              item.product?.images?.[0]?.url ||
                              "https://images.unsplash.com/photo-1582562124811-c09040d0a901?w=800"
                            }
                            alt={item.product?.title_en || "Craft"}
                            className="w-14 h-14 rounded-xl object-cover bg-stone-100"
                          />
                          <div>
                            <h4 className="font-serif font-bold text-stone-900 text-sm">
                              {item.product?.title_en || "Handcrafted Product"}
                            </h4>
                            <p className="text-xs text-stone-500">
                              Qty: {item.quantity} • ₹{item.unit_price?.toLocaleString("en-IN")} each
                            </p>
                          </div>
                        </div>
                        <span className="font-bold text-stone-900">
                          ₹{((item.unit_price || 0) * item.quantity).toLocaleString("en-IN")}
                        </span>
                      </div>
                    ))}
                  </div>

                  <div className="pt-2 flex justify-between items-baseline text-sm font-semibold border-t border-stone-100">
                    <span className="text-stone-500 capitalize">
                      Payment via {o.payment_method || "Online"}
                    </span>
                    <span className="text-lg font-serif font-extrabold text-stone-900">
                      ₹{o.total?.toLocaleString("en-IN")}
                    </span>
                  </div>
                </div>
              ))
            )}
          </div>
        )}

        {/* TAB 2: ADDRESSES */}
        {activeTab === "addresses" && (
          <div className="max-w-lg">
            {savedAddresses.length === 0 ? (
              <div className="bg-white rounded-3xl p-8 border border-stone-200/80 text-center">
                <MapPin className="w-8 h-8 text-stone-400 mx-auto mb-2" />
                <h4 className="font-bold text-sm text-stone-800">No saved addresses yet</h4>
                <p className="text-xs text-stone-500 mt-1">
                  Your delivery address will be saved here automatically when you place an order.
                </p>
              </div>
            ) : (
              <div className="space-y-4">
                {savedAddresses.map((addr, idx) => (
                  <div
                    key={idx}
                    className="bg-white rounded-3xl p-6 sm:p-8 border border-stone-200/80 shadow-sm"
                  >
                    <div className="flex items-center justify-between mb-3">
                      <span className="font-bold text-stone-900 text-sm">
                        {addr.name || "Delivery Address"}
                      </span>
                      {idx === 0 && (
                        <span className="px-2 py-0.5 rounded text-[10px] font-bold bg-stone-100 text-stone-600">
                          Default
                        </span>
                      )}
                    </div>
                    <p className="text-stone-700 text-sm leading-relaxed">
                      {addr.line1}
                      {addr.line2 && <><br />{addr.line2}</>}
                      <br />
                      {addr.city}, {addr.state} - {addr.pincode}
                      {addr.phone && (
                        <>
                          <br />
                          <span className="text-stone-500 text-xs">Phone: {addr.phone}</span>
                        </>
                      )}
                    </p>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}

        {/* TAB 3: WISHLIST */}
        {activeTab === "wishlist" && (
          <div>
            {wishlistLoading ? (
              <div className="bg-white rounded-3xl p-12 text-center border border-stone-200/80">
                <div className="w-8 h-8 border-3 border-[#C85A32] border-t-transparent rounded-full animate-spin mx-auto mb-3" />
                <p className="text-xs text-stone-500">Loading your wishlist...</p>
              </div>
            ) : wishlist.length === 0 ? (
              <div className="bg-white rounded-3xl p-10 border border-stone-200/80 shadow-sm text-center max-w-md mx-auto">
                <Heart className="w-12 h-12 text-stone-300 mx-auto mb-3" />
                <h3 className="font-serif text-lg font-bold text-stone-900 mb-1">
                  Your Wishlist is Empty
                </h3>
                <p className="text-stone-500 text-xs max-w-sm mx-auto mb-5 leading-relaxed">
                  Save handcrafted treasures while browsing so you can easily purchase them later.
                </p>
                <Link
                  href="/products"
                  className="inline-flex px-6 py-2.5 rounded-xl bg-[#C85A32] text-white text-xs font-semibold hover:bg-[#B34D28] transition"
                >
                  Explore Catalog
                </Link>
              </div>
            ) : (
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
                {wishlist.map((item) => {
                  const p = item.product;
                  const img =
                    p?.images?.[0]?.url ||
                    "https://images.unsplash.com/photo-1582562124811-c09040d0a901?w=800";
                  return (
                    <div
                      key={item.id}
                      className="bg-white rounded-2xl overflow-hidden border border-stone-200/80 shadow-sm flex flex-col justify-between"
                    >
                      <div>
                        <div className="relative aspect-square w-full bg-stone-100 overflow-hidden">
                          <img
                            src={img}
                            alt={p?.title_en || "Product"}
                            className="w-full h-full object-cover"
                          />
                          <button
                            onClick={() => handleRemoveWishlist(p.id)}
                            className="absolute top-3 right-3 p-2 rounded-full bg-white/90 text-red-500 hover:bg-white shadow transition"
                            title="Remove from wishlist"
                          >
                            <Trash2 className="w-4 h-4" />
                          </button>
                        </div>
                        <div className="p-4">
                          <h4 className="font-serif font-bold text-stone-900 text-sm line-clamp-1">
                            {p?.title_en}
                          </h4>
                          <span className="text-sm font-bold text-stone-900 block mt-1">
                            ₹{p?.price?.toLocaleString("en-IN")}
                          </span>
                        </div>
                      </div>
                      <div className="p-4 pt-0">
                        <button
                          onClick={() => addToCart(p, 1)}
                          className="w-full py-2 bg-[#C85A32] text-white text-xs font-semibold rounded-xl hover:bg-[#B34D28] transition"
                        >
                          Add to Cart
                        </button>
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
