"use client";

import { useState, useEffect } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import {
  Package, TrendingUp, IndianRupee, Bell, Star, Clock,
  CheckCircle, XCircle, Truck, ShoppingBag, Eye, Plus,
  BarChart2, ArrowUpRight, Palette, MapPin, Award,
  ChevronRight, LogOut,
} from "lucide-react";
import { useAuth } from "@/lib/auth-context";

const statusConfig: Record<string, { label: string; color: string; icon: React.ElementType }> = {
  pending:    { label: "Pending",    color: "bg-amber-50 text-amber-800 border-amber-200",    icon: Clock },
  accepted:   { label: "Accepted",   color: "bg-blue-50 text-blue-800 border-blue-200",        icon: CheckCircle },
  packed:     { label: "Packed",     color: "bg-purple-50 text-purple-800 border-purple-200",  icon: Package },
  shipped:    { label: "Shipped",    color: "bg-indigo-50 text-indigo-800 border-indigo-200",  icon: Truck },
  delivered:  { label: "Delivered",  color: "bg-emerald-50 text-emerald-800 border-emerald-200", icon: CheckCircle },
  cancelled:  { label: "Cancelled",  color: "bg-red-50 text-red-800 border-red-200",           icon: XCircle },
};

const SAMPLE_ORDERS = [
  { id: 1045, product: "Warli Village Canvas", buyer: "Priya M.", quantity: 1, amount: 1800, status: "pending",   date: "Today, 9:15 AM" },
  { id: 1038, product: "Terracotta Pitcher",   buyer: "Rohit K.", quantity: 2, amount: 1100, status: "shipped",   date: "Oct 15, 2026" },
  { id: 1029, product: "Warli Harvest Canvas", buyer: "Aasha S.", quantity: 1, amount: 1800, status: "delivered", date: "Oct 12, 2026" },
  { id: 1021, product: "Terracotta Bowl Set",  buyer: "Neha T.", quantity: 3, amount: 900,  status: "delivered", date: "Oct 8, 2026" },
];

const SAMPLE_PRODUCTS = [
  { id: 1, title: "Warli Village Canvas",     price: 1800, stock: 4, status: "published", views: 124, orders: 8  },
  { id: 2, title: "Terracotta Long Pitcher",  price: 550,  stock: 7, status: "published", views: 89,  orders: 12 },
  { id: 3, title: "Warli Sacred Dance Print", price: 2200, stock: 2, status: "draft",     views: 0,   orders: 0  },
  { id: 4, title: "Terracotta Bowl Set",      price: 300,  stock: 0, status: "sold_out",  views: 67,  orders: 6  },
];

const MONTHLY_EARNINGS = [
  { month: "Jul", amount: 4200 },
  { month: "Aug", amount: 6800 },
  { month: "Sep", amount: 5100 },
  { month: "Oct", amount: 8350 },
];

export default function ArtisanDashboardPage() {
  const { user, isLoggedIn, isArtisan, logout, isLoading } = useAuth();
  const router = useRouter();
  const [activeTab, setActiveTab] = useState<"overview" | "orders" | "products" | "earnings">("overview");

  useEffect(() => {
    if (!isLoading && (!isLoggedIn || !isArtisan)) {
      router.replace("/login?redirect=/artisan/dashboard");
    }
  }, [isLoading, isLoggedIn, isArtisan, router]);

  if (isLoading) {
    return (
      <div className="min-h-screen bg-[#FAF7F2] flex items-center justify-center">
        <div className="w-10 h-10 border-4 border-[#C85A32] border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  if (!isLoggedIn || !isArtisan) return null;

  const totalEarnings = MONTHLY_EARNINGS.reduce((s, m) => s + m.amount, 0);
  const maxBar = Math.max(...MONTHLY_EARNINGS.map((m) => m.amount));
  const pendingOrders = SAMPLE_ORDERS.filter((o) => o.status === "pending").length;

  const handleLogout = () => {
    logout();
    router.replace("/");
  };

  return (
    <div className="min-h-screen bg-[#FAF7F2]">
      {/* Dashboard Header */}
      <div className="bg-gradient-to-r from-[#2C3E6B] to-[#1A2544] text-white px-4 py-6">
        <div className="max-w-6xl mx-auto">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <div className="flex items-center gap-4">
              <div className="w-14 h-14 rounded-2xl bg-white/15 border border-white/20 flex items-center justify-center">
                <Palette className="w-7 h-7 text-[#E09F3E]" />
              </div>
              <div>
                <h1 className="text-xl font-serif font-bold">{user?.name || "Artisan"}</h1>
                <div className="flex items-center gap-2 text-xs text-white/70 mt-0.5">
                  <Award className="w-3.5 h-3.5 text-[#E09F3E]" />
                  <span>Verified Artisan</span>
                  <span className="text-white/30">•</span>
                  <MapPin className="w-3 h-3" />
                  <span>Maharashtra</span>
                </div>
              </div>
            </div>

            <div className="flex items-center gap-3">
              {pendingOrders > 0 && (
                <button className="relative flex items-center gap-1.5 px-3.5 py-2 rounded-xl bg-white/15 border border-white/20 text-xs font-semibold hover:bg-white/20 transition">
                  <Bell className="w-4 h-4 text-[#E09F3E]" />
                  <span>{pendingOrders} new order{pendingOrders > 1 ? "s" : ""}</span>
                  <span className="absolute -top-1.5 -right-1.5 w-4 h-4 bg-[#C85A32] rounded-full text-[10px] font-bold flex items-center justify-center">
                    {pendingOrders}
                  </span>
                </button>
              )}
              <Link
                href="/products"
                className="flex items-center gap-1.5 px-3.5 py-2 rounded-xl bg-[#E09F3E] text-[#1A2544] text-xs font-bold hover:bg-[#D08F2E] transition"
              >
                <Eye className="w-3.5 h-3.5" />
                View My Shop
              </Link>
              <button
                onClick={handleLogout}
                className="flex items-center gap-1.5 px-3.5 py-2 rounded-xl bg-white/10 border border-white/20 text-xs font-semibold hover:bg-white/20 transition"
              >
                <LogOut className="w-3.5 h-3.5" />
                Sign Out
              </button>
            </div>
          </div>

          {/* Tabs */}
          <div className="flex gap-1 mt-6 bg-white/10 rounded-xl p-1 w-fit">
            {(["overview", "orders", "products", "earnings"] as const).map((tab) => (
              <button
                key={tab}
                id={`artisan-tab-${tab}`}
                onClick={() => setActiveTab(tab)}
                className={`px-4 py-1.5 rounded-lg text-xs font-semibold capitalize transition-all ${
                  activeTab === tab ? "bg-white text-[#2C3E6B] shadow" : "text-white/70 hover:text-white"
                }`}
              >
                {tab}
              </button>
            ))}
          </div>
        </div>
      </div>

      <div className="max-w-6xl mx-auto px-4 py-8 space-y-6">
        {/* OVERVIEW */}
        {activeTab === "overview" && (
          <>
            {/* Stats Grid */}
            <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
              {[
                { label: "Total Earnings", value: `₹${totalEarnings.toLocaleString("en-IN")}`, sub: "This year", icon: IndianRupee, color: "text-emerald-600", bg: "bg-emerald-50" },
                { label: "Active Products", value: SAMPLE_PRODUCTS.filter(p => p.status === "published").length.toString(), sub: `${SAMPLE_PRODUCTS.length} total`, icon: Package, color: "text-[#2C3E6B]", bg: "bg-[#2C3E6B]/10" },
                { label: "Pending Orders", value: pendingOrders.toString(), sub: "Awaiting action", icon: Clock, color: "text-amber-600", bg: "bg-amber-50" },
                { label: "Total Views", value: SAMPLE_PRODUCTS.reduce((s, p) => s + p.views, 0).toString(), sub: "Product page views", icon: Eye, color: "text-[#C85A32]", bg: "bg-[#C85A32]/10" },
              ].map((stat) => (
                <div key={stat.label} className="bg-white rounded-2xl p-5 border border-stone-200/80 shadow-sm">
                  <div className={`w-10 h-10 rounded-xl ${stat.bg} flex items-center justify-center mb-3`}>
                    <stat.icon className={`w-5 h-5 ${stat.color}`} />
                  </div>
                  <div className={`text-2xl font-extrabold ${stat.color}`}>{stat.value}</div>
                  <div className="text-xs font-semibold text-stone-700 mt-0.5">{stat.label}</div>
                  <div className="text-xs text-stone-400">{stat.sub}</div>
                </div>
              ))}
            </div>

            {/* Recent Orders + Quick Actions */}
            <div className="grid lg:grid-cols-3 gap-6">
              {/* Recent Orders */}
              <div className="lg:col-span-2 bg-white rounded-2xl border border-stone-200/80 shadow-sm overflow-hidden">
                <div className="px-6 py-4 border-b border-stone-100 flex items-center justify-between">
                  <h2 className="font-serif font-bold text-stone-900">Recent Orders</h2>
                  <button onClick={() => setActiveTab("orders")} className="text-xs font-semibold text-[#C85A32] hover:underline flex items-center gap-1">
                    View all <ChevronRight className="w-3 h-3" />
                  </button>
                </div>
                <div className="divide-y divide-stone-100">
                  {SAMPLE_ORDERS.slice(0, 3).map((o) => {
                    const cfg = statusConfig[o.status] || statusConfig.pending;
                    const Icon = cfg.icon;
                    return (
                      <div key={o.id} className="px-6 py-4 flex items-center justify-between gap-3">
                        <div className="flex items-center gap-3">
                          <div className="w-8 h-8 rounded-lg bg-stone-100 flex items-center justify-center">
                            <ShoppingBag className="w-4 h-4 text-stone-500" />
                          </div>
                          <div>
                            <p className="text-sm font-semibold text-stone-900">{o.product}</p>
                            <p className="text-xs text-stone-500">{o.buyer} • {o.date}</p>
                          </div>
                        </div>
                        <div className="flex items-center gap-3 flex-shrink-0">
                          <span className="font-bold text-stone-900 text-sm">₹{o.amount.toLocaleString("en-IN")}</span>
                          <span className={`flex items-center gap-1 px-2.5 py-1 rounded-full text-[11px] font-bold border ${cfg.color}`}>
                            <Icon className="w-3 h-3" />
                            {cfg.label}
                          </span>
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>

              {/* Quick Actions */}
              <div className="space-y-4">
                <div className="bg-gradient-to-br from-[#C85A32] to-[#A8441E] rounded-2xl p-5 text-white shadow">
                  <p className="text-xs font-semibold text-white/70 uppercase tracking-wider mb-1">New Product</p>
                  <p className="font-serif text-lg font-bold mb-3">Add a craft to your catalog</p>
                  <button className="flex items-center gap-2 px-4 py-2.5 rounded-xl bg-white text-[#C85A32] text-xs font-bold hover:bg-white/90 transition">
                    <Plus className="w-4 h-4" />
                    Create Product
                  </button>
                </div>

                <div className="bg-white rounded-2xl p-5 border border-stone-200/80 shadow-sm">
                  <p className="text-xs font-semibold text-stone-500 uppercase tracking-wider mb-3">This Month</p>
                  {MONTHLY_EARNINGS.slice(-1).map((m) => (
                    <div key={m.month}>
                      <div className="text-2xl font-extrabold text-emerald-600">₹{m.amount.toLocaleString("en-IN")}</div>
                      <div className="text-xs text-stone-500 mt-0.5">{m.month} 2026 earnings</div>
                    </div>
                  ))}
                  <div className="flex items-center gap-1 text-emerald-600 text-xs font-semibold mt-2">
                    <ArrowUpRight className="w-3.5 h-3.5" /> +63% vs last month
                  </div>
                </div>
              </div>
            </div>
          </>
        )}

        {/* ORDERS TAB */}
        {activeTab === "orders" && (
          <div className="bg-white rounded-2xl border border-stone-200/80 shadow-sm overflow-hidden">
            <div className="px-6 py-5 border-b border-stone-100 flex items-center justify-between">
              <h2 className="font-serif text-xl font-bold text-stone-900">All Orders</h2>
              <span className="text-xs text-stone-500">{SAMPLE_ORDERS.length} orders</span>
            </div>
            <div className="divide-y divide-stone-100">
              {SAMPLE_ORDERS.map((o) => {
                const cfg = statusConfig[o.status] || statusConfig.pending;
                const Icon = cfg.icon;
                return (
                  <div key={o.id} className="px-6 py-5 flex flex-col sm:flex-row sm:items-center justify-between gap-4">
                    <div className="flex items-center gap-4">
                      <div className="w-10 h-10 rounded-xl bg-stone-100 flex items-center justify-center flex-shrink-0">
                        <ShoppingBag className="w-5 h-5 text-stone-500" />
                      </div>
                      <div>
                        <p className="font-semibold text-stone-900">Order #{o.id}</p>
                        <p className="text-sm text-stone-700 font-medium">{o.product}</p>
                        <p className="text-xs text-stone-500">
                          {o.buyer} • Qty: {o.quantity} • {o.date}
                        </p>
                      </div>
                    </div>
                    <div className="flex items-center gap-3 flex-shrink-0">
                      <span className="font-bold text-stone-900">₹{o.amount.toLocaleString("en-IN")}</span>
                      <span className={`flex items-center gap-1 px-3 py-1.5 rounded-full text-xs font-bold border ${cfg.color}`}>
                        <Icon className="w-3.5 h-3.5" />
                        {cfg.label}
                      </span>
                      {o.status === "pending" && (
                        <button className="px-4 py-1.5 rounded-xl bg-[#2C3E6B] text-white text-xs font-semibold hover:bg-[#1A2544] transition">
                          Accept
                        </button>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        )}

        {/* PRODUCTS TAB */}
        {activeTab === "products" && (
          <div>
            <div className="flex justify-between items-center mb-4">
              <h2 className="font-serif text-xl font-bold text-stone-900">My Products</h2>
              <button className="flex items-center gap-2 px-4 py-2 rounded-xl bg-[#C85A32] text-white text-sm font-semibold hover:bg-[#B34D28] transition">
                <Plus className="w-4 h-4" />
                Add Product
              </button>
            </div>
            <div className="grid md:grid-cols-2 gap-4">
              {SAMPLE_PRODUCTS.map((p) => (
                <div key={p.id} className="bg-white rounded-2xl border border-stone-200/80 shadow-sm p-5 flex items-center justify-between gap-4">
                  <div className="flex items-center gap-4">
                    <div className="w-12 h-12 rounded-xl bg-stone-100 flex items-center justify-center flex-shrink-0">
                      <Palette className="w-6 h-6 text-stone-400" />
                    </div>
                    <div>
                      <p className="font-semibold text-stone-900 text-sm">{p.title}</p>
                      <p className="text-xs text-stone-500">₹{p.price.toLocaleString("en-IN")} • Stock: {p.stock}</p>
                      <div className="flex items-center gap-3 mt-1 text-xs text-stone-400">
                        <span className="flex items-center gap-0.5"><Eye className="w-3 h-3" /> {p.views}</span>
                        <span className="flex items-center gap-0.5"><ShoppingBag className="w-3 h-3" /> {p.orders} sold</span>
                      </div>
                    </div>
                  </div>
                  <div className="flex flex-col items-end gap-2">
                    <span className={`px-2.5 py-1 rounded-full text-[11px] font-bold capitalize ${
                      p.status === "published" ? "bg-emerald-100 text-emerald-700" :
                      p.status === "draft" ? "bg-stone-100 text-stone-600" :
                      "bg-red-100 text-red-600"
                    }`}>
                      {p.status.replace("_", " ")}
                    </span>
                    <button className="text-xs text-[#C85A32] font-semibold hover:underline">Edit</button>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* EARNINGS TAB */}
        {activeTab === "earnings" && (
          <div className="space-y-6">
            <div className="grid sm:grid-cols-3 gap-4">
              {[
                { label: "Total Earnings", value: `₹${totalEarnings.toLocaleString("en-IN")}`, color: "text-emerald-600" },
                { label: "This Month", value: `₹${MONTHLY_EARNINGS[3].amount.toLocaleString("en-IN")}`, color: "text-[#2C3E6B]" },
                { label: "Pending Payout", value: "₹2,400", color: "text-amber-600" },
              ].map((s) => (
                <div key={s.label} className="bg-white rounded-2xl border border-stone-200/80 shadow-sm p-5 text-center">
                  <div className={`text-3xl font-extrabold ${s.color}`}>{s.value}</div>
                  <div className="text-xs font-semibold text-stone-500 mt-1">{s.label}</div>
                </div>
              ))}
            </div>

            {/* Bar Chart */}
            <div className="bg-white rounded-2xl border border-stone-200/80 shadow-sm p-6">
              <div className="flex items-center gap-2 mb-6">
                <BarChart2 className="w-5 h-5 text-[#2C3E6B]" />
                <h3 className="font-serif font-bold text-stone-900">Monthly Earnings</h3>
              </div>
              <div className="flex items-end justify-around gap-4 h-40">
                {MONTHLY_EARNINGS.map((m) => (
                  <div key={m.month} className="flex flex-col items-center gap-2 flex-1">
                    <span className="text-xs font-bold text-emerald-600">₹{(m.amount / 1000).toFixed(1)}k</span>
                    <div
                      className="w-full rounded-t-lg bg-gradient-to-t from-[#2C3E6B] to-[#3D5A9E] transition-all duration-500"
                      style={{ height: `${(m.amount / maxBar) * 120}px` }}
                    />
                    <span className="text-xs font-semibold text-stone-500">{m.month}</span>
                  </div>
                ))}
              </div>
            </div>

            <div className="bg-emerald-50 border border-emerald-200 rounded-2xl p-5">
              <div className="flex items-start gap-3">
                <IndianRupee className="w-5 h-5 text-emerald-600 flex-shrink-0 mt-0.5" />
                <div>
                  <p className="font-semibold text-emerald-800 text-sm">Payouts via Razorpay</p>
                  <p className="text-xs text-emerald-700 mt-1">
                    Earnings are settled directly to your linked bank account every 7 days.
                    Next payout: <span className="font-bold">October 24, 2026</span>.
                  </p>
                </div>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
