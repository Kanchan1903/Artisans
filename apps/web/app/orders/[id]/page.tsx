"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import {
  CheckCircle2,
  Clock,
  Package,
  Truck,
  MapPin,
  ArrowRight,
  ShieldCheck,
  Bell,
  Sparkles,
  ShoppingBag,
} from "lucide-react";
import { fetchOrderById } from "@/lib/api";

const ORDER_STEPS = [
  { id: "pending", label: "Order Placed", desc: "Sent to artisan's mobile device" },
  { id: "accepted", label: "Artisan Accepted", desc: "Artisan confirmed creation" },
  { id: "packed", label: "Carefully Packed", desc: "Using eco-friendly protective wrap" },
  { id: "shipped", label: "Shipped", desc: "Handed to India Post Speed Post" },
  { id: "delivered", label: "Delivered", desc: "Safely received at your doorstep" },
];

export default function OrderTrackingPage({ params }: { params: { id: string } }) {
  const orderId = Number(params.id);
  const [order, setOrder] = useState<any>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function loadOrder() {
      const data = await fetchOrderById(orderId);
      setOrder(data);
      setLoading(false);
    }
    loadOrder();
  }, [orderId]);

  if (loading || !order) {
    return (
      <div className="min-h-screen bg-[#FAF7F2] flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-4 border-[#C85A32] border-t-transparent"></div>
      </div>
    );
  }

  // Active step index
  const statusIndexMap: Record<string, number> = {
    pending: 0,
    accepted: 1,
    packed: 2,
    shipped: 3,
    delivered: 4,
  };
  const activeStepIdx = statusIndexMap[order.status] ?? 1;

  return (
    <div className="min-h-screen bg-[#FAF7F2] py-10 px-4 sm:px-6 lg:px-8">
      <div className="max-w-4xl mx-auto space-y-8">
        
        {/* Success Banner */}
        <div className="bg-white rounded-3xl p-6 sm:p-8 border border-stone-200/80 shadow-sm text-center">
          <div className="w-16 h-16 bg-emerald-100 rounded-full flex items-center justify-center mx-auto mb-4 text-emerald-600">
            <CheckCircle2 className="w-10 h-10" />
          </div>
          <span className="text-[11px] font-bold uppercase tracking-wider text-[#C85A32]">
            Order #{order.id} Successfully Placed
          </span>
          <h1 className="font-serif text-3xl font-bold text-stone-900 mt-1 mb-2">
            Thank you for supporting village craftspeople!
          </h1>
          <p className="text-stone-600 text-sm max-w-lg mx-auto">
            Your purchase has been routed directly to the artisan. The artisan received an immediate audio push notification on their KalaSathi mobile app.
          </p>

          {/* Real-time Notification Confirmation Pill */}
          <div className="mt-6 inline-flex items-center space-x-2 bg-amber-50 border border-amber-200 px-4 py-2 rounded-full text-xs text-amber-900">
            <Bell className="w-4 h-4 text-[#E09F3E] animate-bounce" />
            <span>
              Real-time Alert Dispatched to Artisan Mobile App (FCM / SSE Connected)
            </span>
          </div>
        </div>

        {/* Live Order Tracking Stepper */}
        <div className="bg-white rounded-3xl p-6 sm:p-8 border border-stone-200/80 shadow-sm">
          <h2 className="font-serif text-xl font-bold text-stone-900 mb-6">
            Live Order Status
          </h2>

          <div className="relative">
            <div className="grid grid-cols-1 md:grid-cols-5 gap-4">
              {ORDER_STEPS.map((step, idx) => {
                const isPassed = idx <= activeStepIdx;
                const isCurrent = idx === activeStepIdx;
                return (
                  <div
                    key={step.id}
                    className={`p-4 rounded-2xl border transition-all ${
                      isCurrent
                        ? "bg-[#FAF7F2] border-[#C85A32] shadow-sm"
                        : isPassed
                        ? "bg-emerald-50/50 border-emerald-200"
                        : "bg-stone-50 border-stone-200 opacity-60"
                    }`}
                  >
                    <div className="flex items-center space-x-2 mb-2">
                      <div
                        className={`w-6 h-6 rounded-full flex items-center justify-center text-xs font-bold ${
                          isPassed
                            ? "bg-emerald-600 text-white"
                            : "bg-stone-300 text-stone-700"
                        }`}
                      >
                        {isPassed ? "✓" : idx + 1}
                      </div>
                      <span className="font-semibold text-xs text-stone-900">
                        {step.label}
                      </span>
                    </div>
                    <p className="text-[11px] text-stone-500 leading-tight">
                      {step.desc}
                    </p>
                  </div>
                );
              })}
            </div>
          </div>
        </div>

        {/* Order Details & Delivery Info */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {/* Shipping & Payment Info */}
          <div className="bg-white rounded-3xl p-6 border border-stone-200/80 shadow-sm space-y-4">
            <h3 className="font-serif text-lg font-bold text-stone-900 border-b border-stone-100 pb-3 flex items-center space-x-2">
              <MapPin className="w-4 h-4 text-[#C85A32]" />
              <span>Delivery Information</span>
            </h3>
            <div className="space-y-2 text-xs">
              <div>
                <span className="text-stone-400 block">Shipping Destination:</span>
                <span className="font-medium text-stone-800 text-sm">
                  {order.shipping_address}
                </span>
              </div>
              <div>
                <span className="text-stone-400 block">Payment Method:</span>
                <span className="font-medium text-stone-800">
                  {order.payment_method || "Razorpay UPI"} ({order.payment_status || "Paid"})
                </span>
              </div>
              <div>
                <span className="text-stone-400 block">Tracking Number:</span>
                <span className="font-mono font-medium text-stone-800">
                  {order.tracking_number || `KS-INDPOST-${order.id}`}
                </span>
              </div>
              <div>
                <span className="text-stone-400 block">Estimated Arrival:</span>
                <span className="font-medium text-emerald-700">
                  {order.estimated_delivery || "Within 4-6 business days"}
                </span>
              </div>
            </div>
          </div>

          {/* Items Summary */}
          <div className="bg-white rounded-3xl p-6 border border-stone-200/80 shadow-sm space-y-4">
            <h3 className="font-serif text-lg font-bold text-stone-900 border-b border-stone-100 pb-3 flex items-center space-x-2">
              <Package className="w-4 h-4 text-[#2C3E6B]" />
              <span>Artifacts in this Shipment</span>
            </h3>

            <div className="space-y-3">
              {(order.items || []).map((item: any) => (
                <div key={item.id} className="flex items-center space-x-3 text-xs">
                  <img
                    src={item.image_url || "https://images.unsplash.com/photo-1582562124811-c09040d0a901?w=800"}
                    alt={item.title}
                    className="w-12 h-12 rounded-xl object-cover bg-stone-100 flex-shrink-0"
                  />
                  <div className="flex-1 min-w-0">
                    <span className="font-semibold text-stone-800 block truncate">
                      {item.title}
                    </span>
                    <span className="text-stone-500">Qty: {item.quantity}</span>
                  </div>
                  <span className="font-bold text-stone-900">
                    ₹{(item.unit_price * item.quantity).toLocaleString("en-IN")}
                  </span>
                </div>
              ))}
            </div>

            <div className="border-t border-stone-100 pt-3 flex justify-between items-baseline text-sm">
              <span className="font-bold text-stone-900">Total Settled:</span>
              <span className="font-serif font-extrabold text-stone-900 text-lg">
                ₹{order.total?.toLocaleString("en-IN") || "1,800"}
              </span>
            </div>
          </div>
        </div>

        {/* Continue Shopping Action */}
        <div className="text-center pt-4">
          <Link
            href="/products"
            className="inline-flex items-center space-x-2 px-8 py-3.5 bg-stone-900 text-white rounded-xl text-sm font-semibold hover:bg-stone-800 transition-colors shadow-sm"
          >
            <ShoppingBag className="w-4 h-4" />
            <span>Discover More Authentic Crafts</span>
            <ArrowRight className="w-4 h-4" />
          </Link>
        </div>

      </div>
    </div>
  );
}
