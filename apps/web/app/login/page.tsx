"use client";

import React, { useState, useEffect, Suspense } from "react";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import {
  Eye, EyeOff, Phone, Lock, Sparkles, ArrowRight,
  Loader2, CheckCircle, ShieldCheck,
} from "lucide-react";
import { useAuth } from "@/lib/auth-context";

// ─── Helper: set HttpOnly-style cookie via API route ─────────────────────────
async function persistTokenCookie(token: string, remember: boolean) {
  try {
    await fetch("/api/auth/session", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ token, remember }),
    });
  } catch (_) {}
}

async function clearTokenCookie() {
  try {
    await fetch("/api/auth/session", { method: "DELETE" });
  } catch (_) {}
}

// ─── OTP Step ─────────────────────────────────────────────────────────────────

function LoginContent() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const redirectTo = searchParams.get("redirect") || "/";
  const { isLoggedIn, isLoading, sendOtp, verifyOtp, token } = useAuth();

  const [tab, setTab] = useState<"signin" | "signup">("signin");
  const [step, setStep] = useState<"phone" | "otp">("phone");

  // Form fields
  const [phone, setPhone] = useState("");
  const [name, setName] = useState("");
  const [otp, setOtp] = useState("");
  const [rememberMe, setRememberMe] = useState(false);

  // UI state
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [otpSent, setOtpSent] = useState(false);
  const [devOtp, setDevOtp] = useState<string | null>(null);
  const [countdown, setCountdown] = useState(0);

  // Redirect if already logged in
  useEffect(() => {
    if (!isLoading && isLoggedIn && token) {
      persistTokenCookie(token, true).then(() => {
        router.replace(redirectTo);
      });
    }
  }, [isLoggedIn, isLoading, token, redirectTo, router]);

  // Countdown timer for OTP resend
  useEffect(() => {
    if (countdown <= 0) return;
    const t = setTimeout(() => setCountdown((c) => c - 1), 1000);
    return () => clearTimeout(t);
  }, [countdown]);

  const formatPhone = (raw: string) => {
    const digits = raw.replace(/\D/g, "");
    if (digits.length <= 10) return digits;
    return digits.slice(-10);
  };

  const fullPhone = `+91${phone}`;

  const handleSendOtp = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    if (phone.length < 10) {
      setError("Enter a valid 10-digit mobile number.");
      return;
    }
    if (tab === "signup" && !name.trim()) {
      setError("Please enter your full name.");
      return;
    }
    setLoading(true);
    try {
      const res = await sendOtp(fullPhone, "buyer");
      setOtpSent(true);
      setStep("otp");
      setCountdown(30);
      if (res.mock_code) setDevOtp(res.mock_code); // Dev only
    } catch (err: any) {
      setError(err.message || "Failed to send OTP. Please try again.");
    } finally {
      setLoading(false);
    }
  };

  const handleVerifyOtp = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    if (otp.length < 4) {
      setError("Enter the 6-digit OTP sent to your number.");
      return;
    }
    setLoading(true);
    try {
      await verifyOtp(fullPhone, otp, tab === "signup" ? name : undefined, "buyer");
      // Persist token in HttpOnly-style cookie
      // token is updated in auth context after verifyOtp resolves
      // We'll get it from localStorage via the context
      const stored = localStorage.getItem("kalasathi_auth");
      if (stored) {
        const auth = JSON.parse(stored);
        await persistTokenCookie(auth.token, rememberMe);
      }
      router.replace(redirectTo);
    } catch (err: any) {
      setError(err.message || "Invalid OTP. Please check and try again.");
    } finally {
      setLoading(false);
    }
  };

  if (isLoading) {
    return (
      <div className="min-h-screen bg-[#FAF7F2] flex items-center justify-center">
        <Loader2 className="w-8 h-8 animate-spin text-[#C85A32]" />
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-[#FAF7F2] via-[#F3EFE6] to-[#EAE2D6] flex flex-col">
      {/* Top Bar */}
      <div className="bg-[#2C3E6B] text-white text-xs py-2 px-4 text-center font-medium">
        🛡️ Direct from Rural Artisans • 100% Fair Wage Guarantee • Authentic Handcrafted GI Crafts
      </div>

      <div className="flex-1 flex items-center justify-center px-4 py-12">
        <div className="w-full max-w-md">
          {/* Logo */}
          <div className="text-center mb-8">
            <Link href="/" className="inline-flex flex-col items-center gap-2">
              <div className="w-14 h-14 rounded-2xl bg-[#C85A32] flex items-center justify-center shadow-lg">
                <span className="text-white font-black text-2xl font-serif">क</span>
              </div>
              <div>
                <span className="font-black text-2xl text-[#262220] font-serif">KalaSathi</span>
                <p className="text-xs text-[#6B645F] font-medium tracking-wider uppercase">कलासाथी • Handicrafts</p>
              </div>
            </Link>
            <p className="text-[#6B645F] text-sm mt-4 max-w-xs mx-auto">
              Authentic Indian handicrafts, direct from artisan to you.
            </p>
          </div>

          {/* Card */}
          <div className="bg-white rounded-3xl shadow-xl border border-[#E5DDD0] overflow-hidden">
            {/* Tabs */}
            <div className="grid grid-cols-2 border-b border-[#E5DDD0]">
              <button
                onClick={() => { setTab("signin"); setStep("phone"); setError(""); setOtp(""); setDevOtp(null); }}
                className={`py-4 text-sm font-bold transition-colors ${
                  tab === "signin"
                    ? "text-[#C85A32] border-b-2 border-[#C85A32] bg-[#FBECE6]/40"
                    : "text-stone-500 hover:text-stone-700"
                }`}
              >
                Sign In
              </button>
              <button
                onClick={() => { setTab("signup"); setStep("phone"); setError(""); setOtp(""); setDevOtp(null); }}
                className={`py-4 text-sm font-bold transition-colors ${
                  tab === "signup"
                    ? "text-[#C85A32] border-b-2 border-[#C85A32] bg-[#FBECE6]/40"
                    : "text-stone-500 hover:text-stone-700"
                }`}
              >
                Create Account
              </button>
            </div>

            <div className="p-7">
              {/* Step: Phone */}
              {step === "phone" && (
                <form onSubmit={handleSendOtp} className="space-y-5">
                  <div>
                    <h2 className="font-serif text-xl font-bold text-stone-900">
                      {tab === "signin" ? "Welcome back!" : "Join KalaSathi"}
                    </h2>
                    <p className="text-stone-500 text-sm mt-1">
                      {tab === "signin"
                        ? "Sign in with your mobile number"
                        : "Create a buyer account to start shopping"}
                    </p>
                  </div>

                  {tab === "signup" && (
                    <div>
                      <label className="block text-xs font-semibold text-stone-600 mb-1.5">
                        Full Name
                      </label>
                      <input
                        type="text"
                        value={name}
                        onChange={(e) => setName(e.target.value)}
                        placeholder="e.g. Priya Sharma"
                        autoComplete="name"
                        className="w-full px-4 py-3 rounded-xl border border-stone-200 bg-stone-50 text-stone-900 placeholder-stone-400 text-sm focus:outline-none focus:ring-2 focus:ring-[#C85A32] focus:border-transparent"
                      />
                    </div>
                  )}

                  <div>
                    <label className="block text-xs font-semibold text-stone-600 mb-1.5">
                      Mobile Number
                    </label>
                    <div className="relative">
                      <div className="absolute left-3 top-1/2 -translate-y-1/2 flex items-center gap-1.5 text-stone-500 text-sm font-semibold pointer-events-none select-none">
                        <Phone className="w-4 h-4" />
                        <span>+91</span>
                        <span className="text-stone-300">|</span>
                      </div>
                      <input
                        type="tel"
                        value={phone}
                        onChange={(e) => setPhone(formatPhone(e.target.value))}
                        placeholder="98765 43210"
                        maxLength={10}
                        autoComplete="tel"
                        inputMode="numeric"
                        className="w-full pl-20 pr-4 py-3 rounded-xl border border-stone-200 bg-stone-50 text-stone-900 placeholder-stone-400 text-sm focus:outline-none focus:ring-2 focus:ring-[#C85A32] focus:border-transparent"
                      />
                    </div>
                    <p className="text-[11px] text-stone-400 mt-1">We'll send a 6-digit OTP to this number</p>
                  </div>

                  {/* Remember Me */}
                  <label className="flex items-start gap-3 cursor-pointer group">
                    <div className="mt-0.5 flex-shrink-0">
                      <input
                        type="checkbox"
                        id="remember-me"
                        checked={rememberMe}
                        onChange={(e) => setRememberMe(e.target.checked)}
                        className="sr-only"
                      />
                      <div
                        onClick={() => setRememberMe(!rememberMe)}
                        className={`w-5 h-5 rounded border-2 flex items-center justify-center transition-colors ${
                          rememberMe
                            ? "bg-[#C85A32] border-[#C85A32]"
                            : "border-stone-300 bg-white group-hover:border-[#C85A32]"
                        }`}
                      >
                        {rememberMe && (
                          <svg className="w-3 h-3 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={3}>
                            <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                          </svg>
                        )}
                      </div>
                    </div>
                    <div>
                      <span className="text-sm text-stone-700 font-medium">Remember me</span>
                      <p className="text-[11px] text-stone-400 mt-0.5">
                        Keep me signed in across browser sessions
                      </p>
                    </div>
                  </label>

                  {error && (
                    <div className="flex items-center gap-2 px-3 py-2.5 bg-red-50 border border-red-200 rounded-xl text-sm text-red-700">
                      <span className="text-red-500">⚠</span> {error}
                    </div>
                  )}

                  <button
                    type="submit"
                    disabled={loading || phone.length < 10}
                    className="w-full py-3.5 px-6 bg-[#C85A32] text-white font-bold rounded-xl flex items-center justify-center gap-2 hover:bg-[#B34D28] disabled:opacity-60 disabled:cursor-not-allowed transition shadow-md shadow-[#C85A32]/20"
                  >
                    {loading ? (
                      <><Loader2 className="w-4 h-4 animate-spin" /> Sending OTP...</>
                    ) : (
                      <>{tab === "signin" ? "Send OTP to Sign In" : "Create Account & Send OTP"} <ArrowRight className="w-4 h-4" /></>
                    )}
                  </button>
                </form>
              )}

              {/* Step: OTP */}
              {step === "otp" && (
                <form onSubmit={handleVerifyOtp} className="space-y-5">
                  <div>
                    <button
                      type="button"
                      onClick={() => { setStep("phone"); setOtp(""); setError(""); setDevOtp(null); }}
                      className="text-[#C85A32] text-sm font-semibold flex items-center gap-1 mb-3 hover:underline"
                    >
                      ← Back
                    </button>
                    <h2 className="font-serif text-xl font-bold text-stone-900">Enter OTP</h2>
                    <p className="text-stone-500 text-sm mt-1">
                      Sent to <strong className="text-stone-700">+91 {phone}</strong>
                    </p>
                  </div>

                  {/* Dev OTP hint */}
                  {devOtp && (
                    <div className="flex items-center gap-2 px-3 py-2.5 bg-blue-50 border border-blue-200 rounded-xl text-sm text-blue-700">
                      <Sparkles className="w-4 h-4 flex-shrink-0" />
                      <span>Dev mode — OTP: <strong className="font-mono">{devOtp}</strong></span>
                    </div>
                  )}

                  <div>
                    <label className="block text-xs font-semibold text-stone-600 mb-1.5">
                      6-Digit OTP
                    </label>
                    <input
                      type="text"
                      inputMode="numeric"
                      value={otp}
                      onChange={(e) => setOtp(e.target.value.replace(/\D/g, "").slice(0, 6))}
                      placeholder="• • • • • •"
                      maxLength={6}
                      autoFocus
                      autoComplete="one-time-code"
                      className="w-full px-4 py-3.5 rounded-xl border border-stone-200 bg-stone-50 text-stone-900 text-xl font-mono tracking-[0.5em] text-center placeholder-stone-300 focus:outline-none focus:ring-2 focus:ring-[#C85A32] focus:border-transparent"
                    />
                  </div>

                  {error && (
                    <div className="flex items-center gap-2 px-3 py-2.5 bg-red-50 border border-red-200 rounded-xl text-sm text-red-700">
                      <span className="text-red-500">⚠</span> {error}
                    </div>
                  )}

                  <button
                    type="submit"
                    disabled={loading || otp.length < 4}
                    className="w-full py-3.5 px-6 bg-[#C85A32] text-white font-bold rounded-xl flex items-center justify-center gap-2 hover:bg-[#B34D28] disabled:opacity-60 disabled:cursor-not-allowed transition shadow-md shadow-[#C85A32]/20"
                  >
                    {loading ? (
                      <><Loader2 className="w-4 h-4 animate-spin" /> Verifying...</>
                    ) : (
                      <><CheckCircle className="w-4 h-4" /> Verify & {tab === "signin" ? "Sign In" : "Create Account"}</>
                    )}
                  </button>

                  {/* Resend */}
                  <p className="text-center text-sm text-stone-500">
                    Didn't receive it?{" "}
                    {countdown > 0 ? (
                      <span className="text-stone-400">Resend in {countdown}s</span>
                    ) : (
                      <button
                        type="button"
                        onClick={handleSendOtp}
                        disabled={loading}
                        className="text-[#C85A32] font-semibold hover:underline disabled:opacity-50"
                      >
                        Resend OTP
                      </button>
                    )}
                  </p>
                </form>
              )}

              {/* Artisan nudge */}
              <div className="mt-6 pt-5 border-t border-stone-100">
                <div className="flex items-start gap-3 p-3 bg-[#FAF7F2] rounded-xl border border-[#E5DDD0]">
                  <Sparkles className="w-4 h-4 text-[#E09F3E] flex-shrink-0 mt-0.5" />
                  <div>
                    <p className="text-xs text-stone-600 font-medium">Are you an artisan?</p>
                    <p className="text-xs text-stone-400 mt-0.5">
                      Download the <strong className="text-stone-600">KalaSathi Mobile App</strong> to list your crafts using voice in your language.
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* Trust badges */}
          <div className="flex items-center justify-center gap-6 mt-6 text-xs text-stone-400">
            <div className="flex items-center gap-1.5">
              <ShieldCheck className="w-3.5 h-3.5 text-emerald-500" />
              <span>OTP Secured</span>
            </div>
            <div className="flex items-center gap-1.5">
              <Lock className="w-3.5 h-3.5 text-emerald-500" />
              <span>No password stored</span>
            </div>
            <div className="flex items-center gap-1.5">
              <span>🇮🇳</span>
              <span>Made in India</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

export default function LoginPage() {
  return (
    <Suspense fallback={
      <div className="min-h-screen bg-[#FAF7F2] flex items-center justify-center">
        <Loader2 className="w-8 h-8 animate-spin text-[#C85A32]" />
      </div>
    }>
      <LoginContent />
    </Suspense>
  );
}
