"use client";

import { Suspense } from "react";
import { useState, useEffect } from "react";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { Smartphone, ShieldCheck, ArrowRight, RefreshCw, Eye, EyeOff, Palette, ShoppingBag } from "lucide-react";
import { useAuth, UserRole } from "@/lib/auth-context";

type Step = "role" | "phone" | "otp";

function LoginContent() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const redirect = searchParams.get("redirect") || "/";
  const { sendOtp, verifyOtp, isLoggedIn, user } = useAuth();

  const [step, setStep] = useState<Step>("role");
  const [role, setRole] = useState<UserRole>("buyer");
  const [phone, setPhone] = useState("+91");
  const [otp, setOtp] = useState("");
  const [mockCode, setMockCode] = useState<string | null>(null);
  const [showMock, setShowMock] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [countdown, setCountdown] = useState(0);

  // Redirect if already logged in
  useEffect(() => {
    if (isLoggedIn && user) {
      if (user.role === "artisan") router.replace("/artisan/dashboard");
      else if (user.role === "admin") router.replace("/admin");
      else router.replace(redirect);
    }
  }, [isLoggedIn, user, redirect, router]);

  // OTP resend countdown
  useEffect(() => {
    if (countdown <= 0) return;
    const t = setTimeout(() => setCountdown((c) => c - 1), 1000);
    return () => clearTimeout(t);
  }, [countdown]);

  const handleSendOtp = async () => {
    setError("");
    const cleaned = phone.replace(/\s/g, "");
    if (!/^\+91[6-9]\d{9}$/.test(cleaned)) {
      setError("Enter a valid 10-digit Indian mobile number starting with +91.");
      return;
    }
    setLoading(true);
    try {
      const data = await sendOtp(cleaned, role);
      setMockCode(data.mock_code || null);
      setStep("otp");
      setCountdown(30);
    } catch (e: any) {
      setError(e.message || "Could not send OTP. Please try again.");
    } finally {
      setLoading(false);
    }
  };

  const handleVerifyOtp = async () => {
    setError("");
    if (otp.length !== 6) {
      setError("Enter the 6-digit OTP sent to your phone.");
      return;
    }
    setLoading(true);
    try {
      await verifyOtp(phone.replace(/\s/g, ""), otp, undefined, role);
      // redirect handled by useEffect above
    } catch (e: any) {
      setError(e.message || "Invalid OTP. Please try again.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-[#FAF7F2] via-[#F5EFE5] to-[#EDE3D5] flex items-center justify-center px-4 py-12">
      {/* Decorative blob */}
      <div className="fixed top-0 right-0 w-96 h-96 bg-[#C85A32]/5 rounded-full -translate-y-1/2 translate-x-1/2 pointer-events-none" />
      <div className="fixed bottom-0 left-0 w-80 h-80 bg-[#2C3E6B]/5 rounded-full translate-y-1/2 -translate-x-1/2 pointer-events-none" />

      <div className="relative w-full max-w-md">
        {/* Brand */}
        <div className="text-center mb-8">
          <Link href="/" className="inline-flex items-center gap-3 group">
            <div className="w-14 h-14 rounded-2xl bg-[#C85A32] flex items-center justify-center shadow-lg shadow-[#C85A32]/30 group-hover:scale-105 transition-transform">
              <span className="text-white font-serif font-black text-3xl">क</span>
            </div>
            <div className="text-left">
              <span className="font-serif text-3xl font-black text-[#262220] tracking-tight">
                Kala<span className="text-[#C85A32]">Sathi</span>
              </span>
              <span className="block text-xs uppercase tracking-widest text-[#6B645F] font-semibold -mt-1">
                कलासाथी • Handicrafts
              </span>
            </div>
          </Link>
          <p className="mt-3 text-sm text-[#6B645F]">
            {step === "role" && "Choose how you want to continue"}
            {step === "phone" && "Enter your mobile number to receive OTP"}
            {step === "otp" && `OTP sent to ${phone}`}
          </p>
        </div>

        <div className="bg-white rounded-3xl shadow-xl shadow-stone-200/60 border border-stone-100 overflow-hidden">
          {/* Progress Bar */}
          <div className="h-1 bg-stone-100">
            <div
              className="h-full bg-gradient-to-r from-[#C85A32] to-[#E09F3E] transition-all duration-500"
              style={{ width: step === "role" ? "33%" : step === "phone" ? "66%" : "100%" }}
            />
          </div>

          <div className="p-8">
            {/* STEP 1: Role Selection */}
            {step === "role" && (
              <div className="space-y-4">
                <h1 className="font-serif text-2xl font-bold text-stone-900 text-center mb-6">
                  Welcome back!
                </h1>
                <p className="text-center text-sm text-stone-500 -mt-4 mb-6">Who are you logging in as?</p>

                <button
                  id="login-as-buyer"
                  onClick={() => { setRole("buyer"); setStep("phone"); }}
                  className="w-full flex items-center gap-4 p-5 rounded-2xl border-2 border-stone-200 hover:border-[#C85A32] hover:bg-[#FFF8F5] transition-all group"
                >
                  <div className="w-12 h-12 rounded-xl bg-[#C85A32]/10 flex items-center justify-center group-hover:bg-[#C85A32]/20 transition-colors">
                    <ShoppingBag className="w-6 h-6 text-[#C85A32]" />
                  </div>
                  <div className="text-left flex-1">
                    <span className="font-bold text-stone-900 block">I&apos;m a Buyer</span>
                    <span className="text-xs text-stone-500">Browse crafts, place orders, track deliveries</span>
                  </div>
                  <ArrowRight className="w-4 h-4 text-stone-400 group-hover:text-[#C85A32] transition-colors" />
                </button>

                <button
                  id="login-as-artisan"
                  onClick={() => { setRole("artisan"); setStep("phone"); }}
                  className="w-full flex items-center gap-4 p-5 rounded-2xl border-2 border-stone-200 hover:border-[#2C3E6B] hover:bg-[#F5F7FF] transition-all group"
                >
                  <div className="w-12 h-12 rounded-xl bg-[#2C3E6B]/10 flex items-center justify-center group-hover:bg-[#2C3E6B]/20 transition-colors">
                    <Palette className="w-6 h-6 text-[#2C3E6B]" />
                  </div>
                  <div className="text-left flex-1">
                    <span className="font-bold text-stone-900 block">I&apos;m an Artisan</span>
                    <span className="text-xs text-stone-500">Manage products, view orders & earnings</span>
                  </div>
                  <ArrowRight className="w-4 h-4 text-stone-400 group-hover:text-[#2C3E6B] transition-colors" />
                </button>

                <div className="pt-2 text-center">
                  <span className="text-xs text-stone-500">New here? </span>
                  <Link href="/signup" className="text-xs font-semibold text-[#C85A32] hover:underline">
                    Create an account
                  </Link>
                </div>
              </div>
            )}

            {/* STEP 2: Phone Entry */}
            {step === "phone" && (
              <div className="space-y-5">
                <div className="flex items-center gap-3 mb-6">
                  <button
                    onClick={() => setStep("role")}
                    className="w-8 h-8 rounded-lg bg-stone-100 flex items-center justify-center hover:bg-stone-200 transition-colors"
                  >
                    <span className="text-stone-600 text-sm">←</span>
                  </button>
                  <div>
                    <h2 className="font-serif text-xl font-bold text-stone-900">
                      {role === "artisan" ? "Artisan Login" : "Buyer Login"}
                    </h2>
                    <p className="text-xs text-stone-500">Sign in with your mobile number</p>
                  </div>
                  <div className={`ml-auto px-2.5 py-1 rounded-full text-xs font-bold ${role === "artisan" ? "bg-[#2C3E6B]/10 text-[#2C3E6B]" : "bg-[#C85A32]/10 text-[#C85A32]"}`}>
                    {role === "artisan" ? "🎨 Artisan" : "🛍️ Buyer"}
                  </div>
                </div>

                <div>
                  <label className="block text-xs font-semibold text-stone-700 mb-2">
                    Mobile Number <span className="text-[#C85A32]">*</span>
                  </label>
                  <div className="relative">
                    <Smartphone className="w-4 h-4 text-stone-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
                    <input
                      id="login-phone"
                      type="tel"
                      value={phone}
                      onChange={(e) => setPhone(e.target.value)}
                      onKeyDown={(e) => e.key === "Enter" && handleSendOtp()}
                      className="w-full pl-10 pr-4 py-3.5 rounded-xl border border-stone-200 focus:outline-none focus:ring-2 focus:ring-[#C85A32] focus:border-transparent text-stone-900 font-medium text-sm transition"
                      placeholder="+91 98XXX XXXXX"
                    />
                  </div>
                  <p className="text-xs text-stone-400 mt-1.5">
                    In demo mode, use <code className="bg-stone-100 px-1 rounded">+919800000001</code> (artisan) or <code className="bg-stone-100 px-1 rounded">+919820000001</code> (buyer)
                  </p>
                </div>

                {error && (
                  <div className="bg-red-50 border border-red-200 text-red-700 text-xs rounded-xl px-4 py-3">
                    {error}
                  </div>
                )}

                <button
                  id="send-otp-btn"
                  onClick={handleSendOtp}
                  disabled={loading}
                  className="w-full py-3.5 rounded-xl bg-[#C85A32] text-white font-bold text-sm hover:bg-[#B34D28] transition-colors disabled:opacity-60 flex items-center justify-center gap-2"
                >
                  {loading ? (
                    <><RefreshCw className="w-4 h-4 animate-spin" /> Sending OTP…</>
                  ) : (
                    <>Send OTP <ArrowRight className="w-4 h-4" /></>
                  )}
                </button>
              </div>
            )}

            {/* STEP 3: OTP Verification */}
            {step === "otp" && (
              <div className="space-y-5">
                <div className="flex items-center gap-3 mb-6">
                  <button
                    onClick={() => { setStep("phone"); setOtp(""); setError(""); }}
                    className="w-8 h-8 rounded-lg bg-stone-100 flex items-center justify-center hover:bg-stone-200 transition-colors"
                  >
                    <span className="text-stone-600 text-sm">←</span>
                  </button>
                  <div>
                    <h2 className="font-serif text-xl font-bold text-stone-900">Enter OTP</h2>
                    <p className="text-xs text-stone-500">6-digit code sent to {phone}</p>
                  </div>
                </div>

                {/* Mock code hint (dev mode) */}
                {mockCode && (
                  <div className="bg-amber-50 border border-amber-200 rounded-xl p-3 flex items-center justify-between">
                    <span className="text-xs text-amber-700 font-medium">
                      🧪 Dev Mode OTP:{" "}
                      <span className={`font-mono font-bold tracking-widest ${showMock ? "" : "blur-sm select-none"}`}>
                        {mockCode}
                      </span>
                    </span>
                    <button
                      onClick={() => { setShowMock(!showMock); if (!showMock) setOtp(mockCode); }}
                      className="text-amber-600 hover:text-amber-800 transition"
                    >
                      {showMock ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                    </button>
                  </div>
                )}

                <div>
                  <label className="block text-xs font-semibold text-stone-700 mb-2">
                    One-Time Password <span className="text-[#C85A32]">*</span>
                  </label>
                  <input
                    id="otp-input"
                    type="text"
                    inputMode="numeric"
                    maxLength={6}
                    value={otp}
                    onChange={(e) => setOtp(e.target.value.replace(/\D/g, ""))}
                    onKeyDown={(e) => e.key === "Enter" && handleVerifyOtp()}
                    className="w-full px-4 py-3.5 rounded-xl border border-stone-200 focus:outline-none focus:ring-2 focus:ring-[#C85A32] focus:border-transparent text-stone-900 font-mono font-bold text-xl text-center tracking-[0.5em] transition"
                    placeholder="• • • • • •"
                  />
                </div>

                {error && (
                  <div className="bg-red-50 border border-red-200 text-red-700 text-xs rounded-xl px-4 py-3">
                    {error}
                  </div>
                )}

                <button
                  id="verify-otp-btn"
                  onClick={handleVerifyOtp}
                  disabled={loading}
                  className="w-full py-3.5 rounded-xl bg-[#C85A32] text-white font-bold text-sm hover:bg-[#B34D28] transition-colors disabled:opacity-60 flex items-center justify-center gap-2"
                >
                  {loading ? (
                    <><RefreshCw className="w-4 h-4 animate-spin" /> Verifying…</>
                  ) : (
                    <><ShieldCheck className="w-4 h-4" /> Verify & Sign In</>
                  )}
                </button>

                <div className="text-center">
                  {countdown > 0 ? (
                    <span className="text-xs text-stone-400">
                      Resend OTP in <span className="font-bold text-stone-600">{countdown}s</span>
                    </span>
                  ) : (
                    <button
                      onClick={() => { handleSendOtp(); }}
                      className="text-xs font-semibold text-[#C85A32] hover:underline"
                    >
                      Didn&apos;t receive OTP? Resend
                    </button>
                  )}
                </div>
              </div>
            )}
          </div>
        </div>

        <p className="text-center text-xs text-stone-400 mt-6">
          By signing in you agree to our{" "}
          <Link href="/" className="text-[#C85A32] hover:underline">Terms of Service</Link>
          {" "}and{" "}
          <Link href="/" className="text-[#C85A32] hover:underline">Privacy Policy</Link>
        </p>
      </div>
    </div>
  );
}

export default function LoginPage() {
  return (
    <Suspense fallback={
      <div className="min-h-screen bg-gradient-to-br from-[#FAF7F2] via-[#F5EFE5] to-[#EDE3D5] flex items-center justify-center">
        <div className="w-10 h-10 border-4 border-[#C85A32] border-t-transparent rounded-full animate-spin" />
      </div>
    }>
      <LoginContent />
    </Suspense>
  );
}
