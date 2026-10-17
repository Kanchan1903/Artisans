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
  Clock,
  Phone,
  Mail,
  ShoppingBag,
  LogOut,
} from "lucide-react";
import { useAuth } from "@/lib/auth-context";

export default function AccountPage() {
  const { user, isLoggedIn, isArtisan, logout, isLoading } = useAuth();
  const router = useRouter();
  const [activeTab, setActiveTab] = useState<"orders" | "addresses" | "wishlist">("orders");

  useEffect(() => {
    if (!isLoading) {
      if (!isLoggedIn) {
        router.replace("/login?redirect=/account");
      } else if (isArtisan) {
        router.replace("/artisan/dashboard");
      }
    }
  }, [isLoading, isLoggedIn, isArtisan, router]);

  if (isLoading || !isLoggedIn || isArtisan) {
    return (
      <div className="min-h-screen bg-[#FAF7F2] flex items-center justify-center">
        <div className="w-10 h-10 border-4 border-[#C85A32] border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  const handleLogout = () => {
    logout();
    router.replace("/");
  };

  const [orders] = useState([
    {
      id: 1042,
      date: "October 17, 2026",
      items: [
        {
          title: "Warli Village Harvest Celebration Canvas",
          artisan: "Sunita Bai Sonawane",
          price: 1800,
          quantity: 1,
          image: "https://images.unsplash.com/photo-1582562124811-c09040d0a901?w=800",
        },
        {
          title: "Terracotta Handcrafted Long-Neck Pitcher",
          artisan: "Sunita Bai Sonawane",
          price: 550,
          quantity: 1,
          image: "https://images.unsplash.com/photo-1578749556568-bc2c40e68b61?w=800",
        },
      ],
      total: 2350,
      status: "accepted",
      tracking: "KS-INDPOST-1042",
    },
    {
      id: 1041,
      date: "October 14, 2026",
      items: [
        {
          title: "Madhubani Tree of Life Mithila Painting",
          artisan: "Rameshwar Chitrakar",
          price: 3200,
          quantity: 1,
          image: "https://images.unsplash.com/photo-1579783902614-a3fb3927b675?w=800",
        },
      ],
      total: 3200,
      status: "packed",
      tracking: "KS-INDPOST-1041",
    },
  ]);

  return (
    <div className="min-h-screen bg-[#FAF7F2] py-10 px-4 sm:px-6 lg:px-8">
      <div className="max-w-6xl mx-auto space-y-8">
        
        {/* Header Breadcrumb */}
        <div className="flex items-center space-x-2 text-xs text-stone-500">
          <Link href="/" className="hover:text-[#C85A32]">Home</Link>
          <ChevronRight className="w-3 h-3 text-stone-400" />
          <span className="text-stone-800 font-medium">Buyer Account</span>
        </div>

        {/* Profile Card & Impact Summary */}
        <div className="bg-white rounded-3xl p-6 sm:p-8 border border-stone-200/80 shadow-sm flex flex-col md:flex-row items-center md:items-start justify-between gap-6">
          <div className="flex items-center space-x-5">
            <div className="w-20 h-20 rounded-2xl bg-[#C85A32]/10 border-2 border-[#C85A32] flex items-center justify-center text-[#C85A32]">
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
              <div className="flex flex-wrap items-center gap-4 text-xs text-stone-500 mt-1">
                <span className="flex items-center gap-1">
                  <Phone className="w-3.5 h-3.5 text-[#C85A32]" />
                  {user?.phone || "+91 —"}
                </span>
                <span className="flex items-center gap-1">
                  <Mail className="w-3.5 h-3.5 text-[#2C3E6B]" />
                  pooja.kulkarni@example.com
                </span>
                <span className="flex items-center gap-1">
                  <MapPin className="w-3.5 h-3.5 text-emerald-600" />
                  Baner, Pune, MH
                </span>
              </div>
            </div>
          </div>

          {/* Right side: impact + logout */}
          <div className="flex flex-col items-end gap-3">
            <div className="bg-[#FAF7F2] p-4 rounded-2xl border border-stone-200 text-center sm:text-right">
              <span className="text-[11px] uppercase tracking-wider text-stone-500 font-semibold block">
                Direct Artisan Impact
              </span>
              <span className="text-2xl font-extrabold text-[#C85A32]">
                ₹5,550
              </span>
              <span className="text-[11px] text-stone-500 block">
                Transferred directly to 2 rural artisan clusters
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
            Saved Addresses (1)
          </button>
          <button
            onClick={() => setActiveTab("wishlist")}
            className={`pb-3 transition-colors ${
              activeTab === "wishlist"
                ? "text-[#C85A32] border-b-2 border-[#C85A32]"
                : "text-stone-500 hover:text-stone-800"
            }`}
          >
            Wishlist
          </button>
        </div>

        {/* TAB 1: ORDERS */}
        {activeTab === "orders" && (
          <div className="space-y-4">
            {orders.map((o) => (
              <div
                key={o.id}
                className="bg-white rounded-3xl p-6 border border-stone-200/80 shadow-sm space-y-4"
              >
                <div className="flex flex-col sm:flex-row sm:items-center justify-between pb-4 border-b border-stone-100 gap-2">
                  <div>
                    <span className="text-xs font-mono font-bold text-stone-900 block">
                      Order #{o.id}
                    </span>
                    <span className="text-xs text-stone-500">Placed on {o.date}</span>
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

                {/* Line items */}
                <div className="divide-y divide-stone-100">
                  {o.items.map((item, idx) => (
                    <div key={idx} className="py-3 flex items-center justify-between text-sm">
                      <div className="flex items-center space-x-4">
                        <img
                          src={item.image}
                          alt={item.title}
                          className="w-14 h-14 rounded-xl object-cover bg-stone-100"
                        />
                        <div>
                          <h4 className="font-serif font-bold text-stone-900 text-sm">
                            {item.title}
                          </h4>
                          <p className="text-xs text-stone-500">
                            Crafted by <span className="font-medium text-stone-700">{item.artisan}</span>
                          </p>
                        </div>
                      </div>
                      <span className="font-bold text-stone-900">
                        ₹{item.price.toLocaleString("en-IN")}
                      </span>
                    </div>
                  ))}
                </div>

                <div className="pt-2 flex justify-between items-baseline text-sm font-semibold border-t border-stone-100">
                  <span className="text-stone-500">Total Settled via Razorpay</span>
                  <span className="text-lg font-serif font-extrabold text-stone-900">
                    ₹{o.total.toLocaleString("en-IN")}
                  </span>
                </div>
              </div>
            ))}
          </div>
        )}

        {/* TAB 2: ADDRESSES */}
        {activeTab === "addresses" && (
          <div className="bg-white rounded-3xl p-6 sm:p-8 border border-stone-200/80 shadow-sm max-w-lg">
            <div className="flex items-center justify-between mb-3">
              <span className="font-bold text-stone-900 text-sm">Default Home Delivery</span>
              <span className="px-2 py-0.5 rounded text-[10px] font-bold bg-stone-100 text-stone-600">
                Primary
              </span>
            </div>
            <p className="text-stone-700 text-sm leading-relaxed mb-4">
              Pooja Kulkarni<br />
              Flat 402, Lotus Towers, Baner<br />
              Pune, Maharashtra - 411045<br />
              Phone: +91 98200 00001
            </p>
            <button className="text-xs font-semibold text-[#C85A32] hover:underline">
              Edit Address
            </button>
          </div>
        )}

        {/* TAB 3: WISHLIST */}
        {activeTab === "wishlist" && (
          <div className="bg-white rounded-3xl p-10 border border-stone-200/80 shadow-sm text-center">
            <Heart className="w-12 h-12 text-[#C85A32] mx-auto mb-3" />
            <h3 className="font-serif text-lg font-bold text-stone-900 mb-1">
              Your Wishlist
            </h3>
            <p className="text-stone-500 text-xs max-w-sm mx-auto mb-4">
              Saved handcrafted treasures directly from village creators.
            </p>
            <Link
              href="/products"
              className="inline-flex px-6 py-2.5 rounded-xl bg-[#C85A32] text-white text-xs font-semibold hover:bg-[#B34D28]"
            >
              Explore Catalog
            </Link>
          </div>
        )}

      </div>
    </div>
  );
}
