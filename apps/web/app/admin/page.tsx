"use client";

import { useState, useEffect } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import {
  Users,
  Package,
  TrendingUp,
  CheckCircle2,
  XCircle,
  Clock,
  ShieldCheck,
  AlertCircle,
  Eye,
  ArrowUpRight,
  Filter,
  Search,
} from "lucide-react";
import { SAMPLE_ARTISANS, SAMPLE_PRODUCTS } from "@/lib/api";
import { useAuth } from "@/lib/auth-context";

export default function AdminDashboardPage() {
  const { user, isLoggedIn, isLoading } = useAuth();
  const router = useRouter();
  const [activeTab, setActiveTab] = useState<"artisans" | "products" | "orders">("artisans");

  useEffect(() => {
    if (!isLoading) {
      if (!isLoggedIn || user?.role !== "admin") {
        router.replace("/login?redirect=/admin");
      }
    }
  }, [isLoading, isLoggedIn, user, router]);

  const [artisans, setArtisans] = useState(
    SAMPLE_ARTISANS.map((a, idx) => ({
      ...a,
      is_approved: idx !== 2,
    }))
  );

  const [products, setProducts] = useState(
    SAMPLE_PRODUCTS.map((p, idx) => ({
      ...p,
      status: idx === 3 ? "pending_review" : "published",
    }))
  );

  const [orders, setOrders] = useState([
    { id: 1042, buyer_name: "Pooja Kulkarni",    items_count: 2, total: 2350, status: "accepted", artisan: "Sunita Bai Sonawane",   date: "2026-10-17 11:20 AM" },
    { id: 1041, buyer_name: "Rajesh Varma",       items_count: 1, total: 3200, status: "packed",   artisan: "Rameshwar Chitrakar",  date: "2026-10-17 09:15 AM" },
    { id: 1040, buyer_name: "Ananya Deshpande",   items_count: 1, total: 650,  status: "shipped",  artisan: "Basavaraju Gudigar",   date: "2026-10-16 04:40 PM" },
  ]);

  if (isLoading || !isLoggedIn || user?.role !== "admin") {
    return (
      <div className="min-h-screen bg-[#FAF7F2] flex items-center justify-center">
        <div className="w-10 h-10 border-4 border-[#C85A32] border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  const toggleArtisanApproval = (id: number, approve: boolean) => {
    setArtisans((prev) =>
      prev.map((a) => (a.id === id ? { ...a, is_approved: approve } : a))
    );
  };

  const toggleProductStatus = (id: number, status: string) => {
    setProducts((prev) =>
      prev.map((p) => (p.id === id ? { ...p, status } : p))
    );
  };

  return (
    <div className="min-h-screen bg-[#FAF7F2] py-8 px-4 sm:px-6 lg:px-8">
      <div className="max-w-7xl mx-auto space-y-8">
        
        {/* Header */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <div className="flex items-center space-x-2 text-xs font-bold uppercase tracking-wider text-[#C85A32] mb-1">
              <ShieldCheck className="w-4 h-4" />
              <span>KalaSathi Trust & Moderation Console</span>
            </div>
            <h1 className="font-serif text-3xl font-bold text-stone-900">
              Guild Administration
            </h1>
            <p className="text-stone-600 text-sm">
              Review voice-digitized catalog submissions, approve new rural artisans, and supervise fulfillment.
            </p>
          </div>
          <div className="flex items-center space-x-3">
            <span className="inline-flex items-center px-3 py-1.5 rounded-full text-xs font-semibold bg-emerald-100 text-emerald-800">
              <span className="w-2 h-2 rounded-full bg-emerald-500 mr-2 animate-pulse"></span>
              Live Microservices Connected
            </span>
          </div>
        </div>

        {/* Analytics Top Cards */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
          <div className="bg-white p-5 rounded-2xl border border-stone-200/80 shadow-sm">
            <div className="flex items-center justify-between text-stone-500 text-xs mb-2">
              <span>Verified Artisans</span>
              <Users className="w-4 h-4 text-[#C85A32]" />
            </div>
            <div className="text-2xl font-bold text-stone-900">
              {artisans.filter((a) => a.is_approved).length} / {artisans.length}
            </div>
            <span className="text-[11px] text-amber-600 font-medium">
              1 pending onboarding verification
            </span>
          </div>

          <div className="bg-white p-5 rounded-2xl border border-stone-200/80 shadow-sm">
            <div className="flex items-center justify-between text-stone-500 text-xs mb-2">
              <span>Published Crafts</span>
              <Package className="w-4 h-4 text-[#2C3E6B]" />
            </div>
            <div className="text-2xl font-bold text-stone-900">
              {products.filter((p) => p.status === "published").length}
            </div>
            <span className="text-[11px] text-emerald-600 font-medium">
              100% Multimodal Cataloged
            </span>
          </div>

          <div className="bg-white p-5 rounded-2xl border border-stone-200/80 shadow-sm">
            <div className="flex items-center justify-between text-stone-500 text-xs mb-2">
              <span>Total Guild Revenue</span>
              <TrendingUp className="w-4 h-4 text-emerald-600" />
            </div>
            <div className="text-2xl font-bold text-stone-900">₹68,450</div>
            <span className="text-[11px] text-emerald-600 font-medium">
              92% direct artisan payout
            </span>
          </div>

          <div className="bg-white p-5 rounded-2xl border border-stone-200/80 shadow-sm">
            <div className="flex items-center justify-between text-stone-500 text-xs mb-2">
              <span>Avg. Fair Wage Index</span>
              <ShieldCheck className="w-4 h-4 text-purple-600" />
            </div>
            <div className="text-2xl font-bold text-stone-900">₹112 / hr</div>
            <span className="text-[11px] text-purple-600 font-medium">
              +32% above statutory min wage
            </span>
          </div>
        </div>

        {/* Tab Switcher */}
        <div className="flex border-b border-stone-200 space-x-6 text-sm font-semibold">
          <button
            onClick={() => setActiveTab("artisans")}
            className={`pb-3 transition-colors relative ${
              activeTab === "artisans"
                ? "text-[#C85A32] border-b-2 border-[#C85A32]"
                : "text-stone-500 hover:text-stone-800"
            }`}
          >
            Artisans Queue ({artisans.length})
          </button>
          <button
            onClick={() => setActiveTab("products")}
            className={`pb-3 transition-colors relative ${
              activeTab === "products"
                ? "text-[#C85A32] border-b-2 border-[#C85A32]"
                : "text-stone-500 hover:text-stone-800"
            }`}
          >
            Product Moderation ({products.length})
          </button>
          <button
            onClick={() => setActiveTab("orders")}
            className={`pb-3 transition-colors relative ${
              activeTab === "orders"
                ? "text-[#C85A32] border-b-2 border-[#C85A32]"
                : "text-stone-500 hover:text-stone-800"
            }`}
          >
            Live Fulfillment Orders ({orders.length})
          </button>
        </div>

        {/* TAB 1: ARTISANS QUEUE */}
        {activeTab === "artisans" && (
          <div className="bg-white rounded-3xl border border-stone-200/80 shadow-sm overflow-hidden">
            <div className="p-6 border-b border-stone-100 flex justify-between items-center">
              <div>
                <h3 className="font-serif text-lg font-bold text-stone-900">
                  Registered Rural Artisans
                </h3>
                <p className="text-xs text-stone-500">
                  Review artisan village credentials, craft heritage, and verify phone OTP status.
                </p>
              </div>
            </div>

            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs">
                <thead className="bg-stone-50 text-stone-500 font-semibold uppercase tracking-wider border-b border-stone-200">
                  <tr>
                    <th className="p-4">Artisan</th>
                    <th className="p-4">Craft Tradition</th>
                    <th className="p-4">Location</th>
                    <th className="p-4">Experience</th>
                    <th className="p-4">Status</th>
                    <th className="p-4 text-right">Moderation Action</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-stone-100">
                  {artisans.map((a) => (
                    <tr key={a.id} className="hover:bg-stone-50/50">
                      <td className="p-4">
                        <div className="flex items-center space-x-3">
                          <img
                            src={a.profile_photo_url}
                            alt={a.name}
                            className="w-10 h-10 rounded-xl object-cover bg-stone-100"
                          />
                          <div>
                            <span className="font-bold text-stone-900 block text-sm">
                              {a.name}
                            </span>
                            <span className="text-stone-400">ID: #ART-{a.id}</span>
                          </div>
                        </div>
                      </td>
                      <td className="p-4 font-medium text-stone-700">
                        {a.craft_type}
                      </td>
                      <td className="p-4 text-stone-600">
                        {a.village}, {a.state}
                      </td>
                      <td className="p-4 text-stone-600">
                        {a.years_experience} Years
                      </td>
                      <td className="p-4">
                        {a.is_approved ? (
                          <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-[11px] font-semibold bg-emerald-100 text-emerald-800">
                            Approved & Live
                          </span>
                        ) : (
                          <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-[11px] font-semibold bg-amber-100 text-amber-800">
                            Pending Review
                          </span>
                        )}
                      </td>
                      <td className="p-4 text-right space-x-2">
                        {a.is_approved ? (
                          <button
                            onClick={() => toggleArtisanApproval(a.id, false)}
                            className="px-3 py-1.5 rounded-lg border border-rose-200 text-rose-600 hover:bg-rose-50 font-medium transition-colors"
                          >
                            Revoke
                          </button>
                        ) : (
                          <button
                            onClick={() => toggleArtisanApproval(a.id, true)}
                            className="px-3 py-1.5 rounded-lg bg-emerald-600 text-white hover:bg-emerald-700 font-medium transition-colors shadow-sm"
                          >
                            Approve Artisan
                          </button>
                        )}
                        <Link
                          href={`/artisans/${a.id}`}
                          className="px-3 py-1.5 rounded-lg border border-stone-200 text-stone-600 hover:bg-stone-50 font-medium inline-block"
                        >
                          View Profile
                        </Link>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* TAB 2: PRODUCTS MODERATION */}
        {activeTab === "products" && (
          <div className="bg-white rounded-3xl border border-stone-200/80 shadow-sm overflow-hidden">
            <div className="p-6 border-b border-stone-100">
              <h3 className="font-serif text-lg font-bold text-stone-900">
                Products Quality & AI Cataloging Control
              </h3>
              <p className="text-xs text-stone-500">
                Ensure pricing meets fair wage floors and image studio enhancements adhere to clarity guidelines.
              </p>
            </div>

            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs">
                <thead className="bg-stone-50 text-stone-500 font-semibold uppercase tracking-wider border-b border-stone-200">
                  <tr>
                    <th className="p-4">Product</th>
                    <th className="p-4">Artisan</th>
                    <th className="p-4">Fair Price</th>
                    <th className="p-4">Stock</th>
                    <th className="p-4">AI Studio</th>
                    <th className="p-4">Status</th>
                    <th className="p-4 text-right">Moderation</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-stone-100">
                  {products.map((p) => {
                    const primaryImg = p.images?.[0]?.url || "https://images.unsplash.com/photo-1582562124811-c09040d0a901?w=800";
                    return (
                      <tr key={p.id} className="hover:bg-stone-50/50">
                        <td className="p-4">
                          <div className="flex items-center space-x-3">
                            <img
                              src={primaryImg}
                              alt={p.title_en}
                              className="w-12 h-12 rounded-xl object-cover bg-stone-100"
                            />
                            <div>
                              <span className="font-bold text-stone-900 block text-sm">
                                {p.title_en}
                              </span>
                              <span className="text-stone-400">ID: #{p.id}</span>
                            </div>
                          </div>
                        </td>
                        <td className="p-4 font-medium text-stone-700">
                          {p.artisan?.name}
                        </td>
                        <td className="p-4 font-bold text-stone-900">
                          ₹{p.price.toLocaleString("en-IN")}
                        </td>
                        <td className="p-4 text-stone-700 font-semibold">
                          {p.stock} units
                        </td>
                        <td className="p-4">
                          <span className="px-2 py-0.5 rounded text-[10px] font-semibold bg-amber-50 text-amber-800 border border-amber-200">
                            1:1 Studio Clean
                          </span>
                        </td>
                        <td className="p-4">
                          {p.status === "published" ? (
                            <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-[11px] font-semibold bg-emerald-100 text-emerald-800">
                              Published
                            </span>
                          ) : (
                            <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-[11px] font-semibold bg-amber-100 text-amber-800">
                              Pending Review
                            </span>
                          )}
                        </td>
                        <td className="p-4 text-right space-x-2">
                          {p.status === "published" ? (
                            <button
                              onClick={() => toggleProductStatus(p.id, "delisted")}
                              className="px-3 py-1.5 rounded-lg border border-stone-200 text-stone-600 hover:bg-stone-50 font-medium"
                            >
                              Delist
                            </button>
                          ) : (
                            <button
                              onClick={() => toggleProductStatus(p.id, "published")}
                              className="px-3 py-1.5 rounded-lg bg-emerald-600 text-white hover:bg-emerald-700 font-medium shadow-sm"
                            >
                              Approve & Publish
                            </button>
                          )}
                          <Link
                            href={`/products/${p.id}`}
                            className="px-3 py-1.5 rounded-lg border border-stone-200 text-stone-600 hover:bg-stone-50 font-medium inline-block"
                          >
                            Preview
                          </Link>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* TAB 3: ORDERS & FULFILLMENT */}
        {activeTab === "orders" && (
          <div className="bg-white rounded-3xl border border-stone-200/80 shadow-sm overflow-hidden">
            <div className="p-6 border-b border-stone-100">
              <h3 className="font-serif text-lg font-bold text-stone-900">
                Live E-Commerce Order Fulfillment
              </h3>
              <p className="text-xs text-stone-500">
                Track status progression synced in real-time with the artisan&apos;s mobile app.
              </p>
            </div>

            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs">
                <thead className="bg-stone-50 text-stone-500 font-semibold uppercase tracking-wider border-b border-stone-200">
                  <tr>
                    <th className="p-4">Order ID</th>
                    <th className="p-4">Buyer</th>
                    <th className="p-4">Artisan Fulfiller</th>
                    <th className="p-4">Amount</th>
                    <th className="p-4">Placed At</th>
                    <th className="p-4">Current Status</th>
                    <th className="p-4 text-right">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-stone-100">
                  {orders.map((o) => (
                    <tr key={o.id} className="hover:bg-stone-50/50">
                      <td className="p-4 font-mono font-bold text-stone-900">
                        #{o.id}
                      </td>
                      <td className="p-4 font-medium text-stone-800">
                        {o.buyer_name}
                      </td>
                      <td className="p-4 text-stone-600">
                        {o.artisan}
                      </td>
                      <td className="p-4 font-extrabold text-stone-900">
                        ₹{o.total.toLocaleString("en-IN")}
                      </td>
                      <td className="p-4 text-stone-500">
                        {o.date}
                      </td>
                      <td className="p-4">
                        <span className="capitalize inline-flex items-center px-2.5 py-0.5 rounded-full text-[11px] font-semibold bg-blue-100 text-[#2C3E6B]">
                          {o.status}
                        </span>
                      </td>
                      <td className="p-4 text-right">
                        <Link
                          href={`/orders/${o.id}`}
                          className="px-3 py-1.5 rounded-lg border border-stone-200 text-stone-700 hover:bg-stone-50 font-medium inline-block"
                        >
                          Track Stepper
                        </Link>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}

      </div>
    </div>
  );
}
