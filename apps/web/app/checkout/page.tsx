"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import {
  ShieldCheck,
  CreditCard,
  Banknote,
  CheckCircle2,
  Lock,
  Truck,
  ArrowLeft,
  ChevronRight,
  User,
} from "lucide-react";
import { useCart } from "@/lib/cart-context";
import { useAuth } from "@/lib/auth-context";
import { createOrder } from "@/lib/api";

export default function CheckoutPage() {
  const router = useRouter();
  const { items, totalPrice, clearCart, refreshCartProducts } = useCart();
  const { user, isLoggedIn, token } = useAuth();

  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [phone, setPhone] = useState("");
  const [street, setStreet] = useState("");
  const [city, setCity] = useState("");
  const [state, setState] = useState("");
  const [pincode, setPincode] = useState("");
  const [paymentMethod, setPaymentMethod] = useState<"razorpay" | "cod">("razorpay");
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [cartRefreshError, setCartRefreshError] = useState<string | null>(null);

  useEffect(() => {
    if (items.length === 0) return;
    refreshCartProducts().then((unavailable) => {
      if (unavailable.length) {
        setCartRefreshError('Some items are no longer available and were removed from your basket.');
      }
    }).catch(() => {
      setCartRefreshError('Could not refresh current product prices. Please try again before ordering.');
    });
  // Refresh when entering checkout; the order API still validates current prices.
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [items.length]);

  // Pre-fill from auth user
  useEffect(() => {
    if (user) {
      setName(user.name || "");
      setPhone(user.phone || "");
    }
  }, [user]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSubmitting(true);
    setCartRefreshError(null);

    try {
      const unavailable = await refreshCartProducts();
      if (unavailable.length) {
        throw new Error('Some items are no longer available and were removed from your basket. Review your basket and try again.');
      }
      const orderPayload = {
        items: items.map((i) => ({
          product_id: i.product.id,
          quantity: i.quantity,
        })),
        shipping_address: {
          name,
          phone,
          line1: street,
          city,
          state,
          pincode,
        },
        payment_method: paymentMethod,
        payment_id: paymentMethod === "razorpay" ? `pay_sim_${Date.now()}` : undefined,
      };

      const result = await createOrder(orderPayload, token || "");
      clearCart();
      const orderId = result.id;
      router.push(`/orders/${orderId}`);
    } catch (err: any) {
      setCartRefreshError(err.message || 'Order could not be processed. Please try again.');
      alert(err.message || "Order could not be processed. Please try again.");
      setIsSubmitting(false);
    }
  };

  if (items.length === 0) {
    return (
      <div className="min-h-screen bg-[#FAF7F2] py-16 px-4 flex items-center justify-center">
        <div className="bg-white rounded-3xl p-8 max-w-md w-full text-center border border-stone-200">
          <h2 className="font-serif text-xl font-bold text-stone-900 mb-2">No items to checkout</h2>
          <p className="text-stone-500 text-sm mb-6">Your basket is empty. Please select crafts to proceed.</p>
          <Link
            href="/products"
            className="inline-flex py-3 px-6 rounded-xl bg-[#C85A32] text-white font-semibold text-sm hover:bg-[#B34D28]"
          >
            Explore Catalog
          </Link>
        </div>
      </div>
    );
  }

  // Auth nudge banner (non-blocking — guests can still checkout)
  const authNudge = !isLoggedIn ? (
    <div className="mb-6 flex items-center gap-3 bg-amber-50 border border-amber-200 rounded-2xl px-5 py-3.5">
      <User className="w-5 h-5 text-amber-600 flex-shrink-0" />
      <p className="text-xs text-amber-800">
        <span className="font-semibold">Save time on future orders.</span>{" "}
        <Link href="/login?redirect=/checkout" className="underline font-bold hover:text-amber-900">Sign in</Link>
        {" "}or{" "}
        <Link href="/signup" className="underline font-bold hover:text-amber-900">create an account</Link>
        {" "}to auto-fill your details.
      </p>
    </div>
  ) : null;

  return (
    <div className="min-h-screen bg-[#FAF7F2] py-10 px-4 sm:px-6 lg:px-8">
      <div className="max-w-6xl mx-auto">
        {/* Breadcrumb */}
        <div className="flex items-center space-x-2 text-xs text-stone-500 mb-6">
          <Link href="/cart" className="hover:text-[#C85A32] flex items-center space-x-1">
            <ArrowLeft className="w-3.5 h-3.5" />
            <span>Back to Cart</span>
          </Link>
          <ChevronRight className="w-3 h-3 text-stone-400" />
          <span className="text-stone-800 font-medium">Checkout</span>
        </div>

        <h1 className="font-serif text-3xl font-bold text-stone-900 mb-6">
          Complete Your Fair Trade Order
        </h1>

        {authNudge}

        {cartRefreshError && (
          <div role="alert" className="mb-5 rounded-xl border border-amber-300 bg-amber-50 px-4 py-3 text-sm text-amber-900">
            {cartRefreshError}
          </div>
        )}

        <form onSubmit={handleSubmit} className="grid grid-cols-1 lg:grid-cols-12 gap-8">
          {/* Shipping and Payment Info (7 cols) */}
          <div className="lg:col-span-7 space-y-6">
            {/* Delivery Address */}
            <div className="bg-white rounded-3xl p-6 sm:p-8 border border-stone-200/80 shadow-sm space-y-4">
              <div className="flex items-center space-x-2 border-b border-stone-100 pb-3">
                <Truck className="w-5 h-5 text-[#C85A32]" />
                <h2 className="font-semibold text-stone-900 text-base">Delivery Details</h2>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div className="sm:col-span-2">
                  <label className="block text-xs font-semibold text-stone-700 mb-1">
                    Full Name *
                  </label>
                  <input
                    type="text"
                    required
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                    className="w-full px-3.5 py-2.5 text-sm border border-stone-300 rounded-xl focus:ring-2 focus:ring-[#C85A32] focus:outline-none"
                  />
                </div>

                <div>
                  <label className="block text-xs font-semibold text-stone-700 mb-1">
                    Email Address *
                  </label>
                  <input
                    type="email"
                    required
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    className="w-full px-3.5 py-2.5 text-sm border border-stone-300 rounded-xl focus:ring-2 focus:ring-[#C85A32] focus:outline-none"
                  />
                </div>

                <div>
                  <label className="block text-xs font-semibold text-stone-700 mb-1">
                    Phone Number (for SMS & Courier) *
                  </label>
                  <input
                    type="tel"
                    required
                    value={phone}
                    onChange={(e) => setPhone(e.target.value)}
                    className="w-full px-3.5 py-2.5 text-sm border border-stone-300 rounded-xl focus:ring-2 focus:ring-[#C85A32] focus:outline-none"
                  />
                </div>

                <div className="sm:col-span-2">
                  <label className="block text-xs font-semibold text-stone-700 mb-1">
                    Street Address / Flat / Landmark *
                  </label>
                  <input
                    type="text"
                    required
                    value={street}
                    onChange={(e) => setStreet(e.target.value)}
                    className="w-full px-3.5 py-2.5 text-sm border border-stone-300 rounded-xl focus:ring-2 focus:ring-[#C85A32] focus:outline-none"
                  />
                </div>

                <div>
                  <label className="block text-xs font-semibold text-stone-700 mb-1">
                    City / Town *
                  </label>
                  <input
                    type="text"
                    required
                    value={city}
                    onChange={(e) => setCity(e.target.value)}
                    className="w-full px-3.5 py-2.5 text-sm border border-stone-300 rounded-xl focus:ring-2 focus:ring-[#C85A32] focus:outline-none"
                  />
                </div>

                <div>
                  <label className="block text-xs font-semibold text-stone-700 mb-1">
                    State *
                  </label>
                  <input
                    type="text"
                    required
                    value={state}
                    onChange={(e) => setState(e.target.value)}
                    className="w-full px-3.5 py-2.5 text-sm border border-stone-300 rounded-xl focus:ring-2 focus:ring-[#C85A32] focus:outline-none"
                  />
                </div>

                <div>
                  <label className="block text-xs font-semibold text-stone-700 mb-1">
                    PIN Code *
                  </label>
                  <input
                    type="text"
                    required
                    value={pincode}
                    onChange={(e) => setPincode(e.target.value)}
                    className="w-full px-3.5 py-2.5 text-sm border border-stone-300 rounded-xl focus:ring-2 focus:ring-[#C85A32] focus:outline-none"
                  />
                </div>
              </div>
            </div>

            {/* Payment Method Selector */}
            <div className="bg-white rounded-3xl p-6 sm:p-8 border border-stone-200/80 shadow-sm space-y-4">
              <div className="flex items-center space-x-2 border-b border-stone-100 pb-3">
                <Lock className="w-5 h-5 text-emerald-600" />
                <h2 className="font-semibold text-stone-900 text-base">Payment Method</h2>
              </div>

              <div className="space-y-3">
                {/* Razorpay Test Mode */}
                <label
                  onClick={() => setPaymentMethod("razorpay")}
                  className={`flex items-start p-4 rounded-2xl border cursor-pointer transition-all ${
                    paymentMethod === "razorpay"
                      ? "border-[#C85A32] bg-[#FAF7F2]"
                      : "border-stone-200 hover:border-stone-300"
                  }`}
                >
                  <input
                    type="radio"
                    name="payment"
                    checked={paymentMethod === "razorpay"}
                    onChange={() => setPaymentMethod("razorpay")}
                    className="mt-1 accent-[#C85A32]"
                  />
                  <div className="ml-3 flex-1">
                    <div className="flex items-center justify-between">
                      <span className="font-semibold text-stone-900 text-sm flex items-center gap-2">
                        <CreditCard className="w-4 h-4 text-[#2C3E6B]" />
                        Razorpay Gateway (UPI, Cards, Netbanking)
                      </span>
                      <span className="text-[10px] font-bold uppercase tracking-wider text-emerald-700 bg-emerald-100 px-2 py-0.5 rounded">
                        Simulated Instant Pay
                      </span>
                    </div>
                    <p className="text-xs text-stone-500 mt-1">
                      Direct settlement into artisan cluster escrow. Instant order confirmation sent to artisan app.
                    </p>
                  </div>
                </label>

                {/* Cash on Delivery */}
                <label
                  onClick={() => setPaymentMethod("cod")}
                  className={`flex items-start p-4 rounded-2xl border cursor-pointer transition-all ${
                    paymentMethod === "cod"
                      ? "border-[#C85A32] bg-[#FAF7F2]"
                      : "border-stone-200 hover:border-stone-300"
                  }`}
                >
                  <input
                    type="radio"
                    name="payment"
                    checked={paymentMethod === "cod"}
                    onChange={() => setPaymentMethod("cod")}
                    className="mt-1 accent-[#C85A32]"
                  />
                  <div className="ml-3 flex-1">
                    <div className="flex items-center justify-between">
                      <span className="font-semibold text-stone-900 text-sm flex items-center gap-2">
                        <Banknote className="w-4 h-4 text-[#E09F3E]" />
                        Cash on Delivery (COD)
                      </span>
                      <span className="text-[10px] text-stone-500">Pay at doorstep</span>
                    </div>
                    <p className="text-xs text-stone-500 mt-1">
                      Pay cash upon delivery. Verified by India Post Speed Post.
                    </p>
                  </div>
                </label>
              </div>
            </div>
          </div>

          {/* Right Column: Order Review (5 cols) */}
          <div className="lg:col-span-5">
            <div className="bg-white rounded-3xl p-6 sm:p-8 border border-stone-200/80 shadow-sm sticky top-24 space-y-6">
              <h3 className="font-serif text-xl font-bold text-stone-900 border-b border-stone-100 pb-4">
                Items in Order
              </h3>

              <div className="space-y-4 max-h-72 overflow-y-auto pr-1">
                {items.map(({ product, quantity }) => (
                  <div key={product.id} className="flex items-center space-x-3 text-sm">
                    <img
                      src={
                        product.images?.[0]?.url ||
                        "https://images.unsplash.com/photo-1582562124811-c09040d0a901?w=800"
                      }
                      alt={product.title_en}
                      className="w-14 h-14 rounded-xl object-cover bg-stone-100 flex-shrink-0"
                    />
                    <div className="flex-1 min-w-0">
                      <h4 className="font-serif font-bold text-stone-900 truncate">
                        {product.title_en}
                      </h4>
                      <p className="text-xs text-stone-500">
                        Qty: {quantity} × ₹{product.price.toLocaleString("en-IN")}
                      </p>
                    </div>
                    <span className="font-bold text-stone-800 text-sm">
                      ₹{(product.price * quantity).toLocaleString("en-IN")}
                    </span>
                  </div>
                ))}
              </div>

              <div className="border-t border-stone-100 pt-4 space-y-2 text-sm">
                <div className="flex justify-between text-stone-600">
                  <span>Subtotal</span>
                  <span>₹{totalPrice.toLocaleString("en-IN")}</span>
                </div>
                <div className="flex justify-between text-stone-600">
                  <span>Artisan Shipping</span>
                  <span className="text-emerald-600 font-semibold">FREE</span>
                </div>
                <div className="pt-3 border-t border-stone-200 flex justify-between items-baseline">
                  <span className="font-serif font-bold text-stone-900 text-lg">Total Amount</span>
                  <span className="text-2xl font-extrabold text-stone-900">
                    ₹{totalPrice.toLocaleString("en-IN")}
                  </span>
                </div>
              </div>

              <button
                type="submit"
                disabled={isSubmitting}
                className="w-full py-4 rounded-xl bg-[#C85A32] text-white font-semibold text-sm hover:bg-[#B34D28] transition-colors flex items-center justify-center space-x-2 shadow-sm disabled:opacity-50"
              >
                <CheckCircle2 className="w-5 h-5" />
                <span>
                  {isSubmitting ? "Broadcasting to Artisan App..." : "Confirm & Place Order"}
                </span>
              </button>

              <div className="text-center text-[11px] text-stone-500">
                <span>By confirming, your order will trigger an instant notification in the artisan’s mobile app.</span>
              </div>
            </div>
          </div>
        </form>
      </div>
    </div>
  );
}
