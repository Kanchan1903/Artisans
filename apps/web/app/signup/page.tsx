"use client";

import { useState, useEffect } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import {
  Smartphone, ShieldCheck, ArrowRight, RefreshCw, Eye, EyeOff,
  Palette, ShoppingBag, User, MapPin,
} from "lucide-react";
import { useAuth, UserRole } from "@/lib/auth-context";

type Step = "role" | "info" | "otp";

export default function SignupPage() {
  const router = useRouter();
  const { sendOtp, verifyOtp, isLoggedIn, user } = useAuth();

  const [step, setStep] = useState<Step>("role");
  const [role, setRole] = useState<UserRole>("buyer");
  const [name, setName] = useState("");
  const [phone, setPhone] = useState("+91");
  const [otp, setOtp] = useState("");
  const [mockCode, setMockCode] = useState<string | null>(null);
  const [showMock, setShowMock] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [countdown, setCountdown] = useState(0);

  useEffect(() => {
    if (isLoggedIn && user) {
      if (user.role === "artisan") router.replace("/artisan/dashboard");
      else router.replace("/account");
    }
  }, [isLoggedIn, user, router]);

  useEffect(() => {
    if (countdown <= 0) return;
    const t = setTimeout(() => setCountdown((c) => c - 1), 1000);
    return () => clearTimeout(t);
  }, [countdown]);

  const handleSendOtp = async () => {
    setError("");
    if (!name.trim() || name.trim().length < 2) {
      setError("Please enter your full name (at least 2 characters).");
      return;
    }
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
      await verifyOtp(phone.replace(/\s/g, ""), otp, name.trim(), role);
    } catch (e: any) {
      setError(e.message || "Invalid OTP. Please try again.");
    } finally {
      setLoading(false);
    }
  };

  const themeColor = role === "artisan" ? "#2C3E6B" : "#C85A32";
  const themeBg = role === "artisan" ? "hover:border-[#2C3E6B] hover:bg-[#F5F7FF]" : "hover:border-[#C85A32] hover:bg-[#FFF8F5]";

  return (
    <div className="min-h-screen bg-gradient-to-br from-[#FAF7F2] via-[#F5EFE5] to-[#EDE3D5] flex items-center justify-center px-4 py-12">
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
                Join the artisan community
              </span>
            </div>
          </Link>
        </div>

        <div className="bg-white rounded-3xl shadow-xl shadow-stone-200/60 border border-stone-100 overflow-hidden">
          {/* Progress Bar */}
          <div className="h-1 bg-stone-100">
            <div
              className="h-full bg-gradient-to-r from-[#C85A32] to-[#E09F3E] transition-all duration-500"
              style={{ width: step === "role" ? "33%" : step === "info" ? "66%" : "100%" }}
            />
          </div>

          <div className="p-8">
            {/* STEP 1: Role */}
            {step === "role" && (
              <div className="space-y-4">
                <h1 className="font-serif text-2xl font-bold text-stone-900 text-center mb-2">Create your account</h1>
                <p className="text-center text-sm text-stone-500 mb-6">How will you use KalaSathi?</p>

                <button
                  id="signup-as-buyer"
                  onClick={() => { setRole("buyer"); setStep("info"); }}
                  className={`w-full flex items-center gap-4 p-5 rounded-2xl border-2 border-stone-200 transition-all group ${themeBg}`}
                >
                  <div className="w-12 h-12 rounded-xl bg-[#C85A32]/10 flex items-center justify-center">
                    <ShoppingBag className="w-6 h-6 text-[#C85A32]" />
                  </div>
                  <div className="text-left flex-1">
                    <span className="font-bold text-stone-900 block">Join as a Buyer</span>
                    <span className="text-xs text-stone-500">Discover authentic Indian handicrafts and support rural artisans</span>
                  </div>
                  <ArrowRight className="w-4 h-4 text-stone-400 group-hover:text-[#C85A32] transition-colors" />
                </button>

                <button
                  id="signup-as-artisan"
                  onClick={() => { setRole("artisan"); setStep("info"); }}
                  className="w-full flex items-center gap-4 p-5 rounded-2xl border-2 border-stone-200 hover:border-[#2C3E6B] hover:bg-[#F5F7FF] transition-all group"
                >
                  <div className="w-12 h-12 rounded-xl bg-[#2C3E6B]/10 flex items-center justify-center">
                    <Palette className="w-6 h-6 text-[#2C3E6B]" />
                  </div>
                  <div className="text-left flex-1">
                    <span className="font-bold text-stone-900 block">Join as an Artisan</span>
                    <span className="text-xs text-stone-500">List your crafts, reach global buyers, receive fair wages</span>
                  </div>
                  <ArrowRight className="w-4 h-4 text-stone-400 group-hover:text-[#2C3E6B] transition-colors" />
                </button>

                <div className="pt-2 text-center">
                  <span className="text-xs text-stone-500">Already have an account? </span>
                  <Link href="/login" className="text-xs font-semibold text-[#C85A32] hover:underline">Sign in</Link>
                </div>
              </div>
            )}

            {/* STEP 2: Info + Phone */}
            {step === "info" && (
              <div className="space-y-5">
                <div className="flex items-center gap-3 mb-6">
                  <button onClick={() => setStep("role")} className="w-8 h-8 rounded-lg bg-stone-100 flex items-center justify-center hover:bg-stone-200 transition-colors">
                    <span className="text-stone-600 text-sm">←</span>
                  </button>
                  <div>
                    <h2 className="font-serif text-xl font-bold text-stone-900">
                      {role === "artisan" ? "Artisan Registration" : "Buyer Registration"}
                    </h2>
                    <p className="text-xs text-stone-500">Your account details</p>
                  </div>
                  <div className={`ml-auto px-2.5 py-1 rounded-full text-xs font-bold ${role === "artisan" ? "bg-[#2C3E6B]/10 text-[#2C3E6B]" : "bg-[#C85A32]/10 text-[#C85A32]"}`}>
                    {role === "artisan" ? "🎨 Artisan" : "🛍️ Buyer"}
                  </div>
                </div>

                <div>
                  <label className="block text-xs font-semibold text-stone-700 mb-2">
                    Full Name <span className="text-[#C85A32]">*</span>
                  </label>
                  <div className="relative">
                    <User className="w-4 h-4 text-stone-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
                    <input
                      id="signup-name"
                      type="text"
                      value={name}
                      onChange={(e) => setName(e.target.value)}
                      className="w-full pl-10 pr-4 py-3.5 rounded-xl border border-stone-200 focus:outline-none focus:ring-2 focus:ring-[#C85A32] text-stone-900 text-sm transition"
                      placeholder={role === "artisan" ? "e.g. Sunita Bai Sonawane" : "e.g. Pooja Kulkarni"}
                    />
                  </div>
                </div>

                <div>
                  <label className="block text-xs font-semibold text-stone-700 mb-2">
                    Mobile Number <span className="text-[#C85A32]">*</span>
                  </label>
                  <div className="relative">
                    <Smartphone className="w-4 h-4 text-stone-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
                    <input
                      id="signup-phone"
                      type="tel"
                      value={phone}
                      onChange={(e) => setPhone(e.target.value)}
                      onKeyDown={(e) => e.key === "Enter" && handleSendOtp()}
                      className="w-full pl-10 pr-4 py-3.5 rounded-xl border border-stone-200 focus:outline-none focus:ring-2 focus:ring-[#C85A32] text-stone-900 font-medium text-sm transition"
                      placeholder="+91 98XXX XXXXX"
                    />
                  </div>
                </div>

                {role === "artisan" && (
                  <div className="bg-[#2C3E6B]/5 rounded-xl p-4 border border-[#2C3E6B]/10">
                    <div className="flex items-start gap-3">
                      <MapPin className="w-4 h-4 text-[#2C3E6B] mt-0.5 flex-shrink-0" />
                      <p className="text-xs text-[#2C3E6B]/80 leading-relaxed">
                        After sign-up, complete your artisan profile with your craft type, village, and district to get approved and start listing products.
                      </p>
                    </div>
                  </div>
                )}

                {error && (
                  <div className="bg-red-50 border border-red-200 text-red-700 text-xs rounded-xl px-4 py-3">{error}</div>
                )}

                <button
                  id="signup-send-otp"
                  onClick={handleSendOtp}
                  disabled={loading}
                  className="w-full py-3.5 rounded-xl font-bold text-sm text-white transition-colors disabled:opacity-60 flex items-center justify-center gap-2"
                  style={{ backgroundColor: themeColor }}
                >
                  {loading ? (
                    <><RefreshCw className="w-4 h-4 animate-spin" /> Sending OTP…</>
                  ) : (
                    <>Send OTP <ArrowRight className="w-4 h-4" /></>
                  )}
                </button>
              </div>
            )}

            {/* STEP 3: OTP */}
            {step === "otp" && (
              <div className="space-y-5">
                <div className="flex items-center gap-3 mb-6">
                  <button onClick={() => { setStep("info"); setOtp(""); setError(""); }} className="w-8 h-8 rounded-lg bg-stone-100 flex items-center justify-center hover:bg-stone-200 transition-colors">
                    <span className="text-stone-600 text-sm">←</span>
                  </button>
                  <div>
                    <h2 className="font-serif text-xl font-bold text-stone-900">Verify Phone</h2>
                    <p className="text-xs text-stone-500">OTP sent to {phone}</p>
                  </div>
                </div>

                {mockCode && (
                  <div className="bg-amber-50 border border-amber-200 rounded-xl p-3 flex items-center justify-between">
                    <span className="text-xs text-amber-700 font-medium">
                      🧪 Dev OTP:{" "}
                      <span className={`font-mono font-bold tracking-widest ${showMock ? "" : "blur-sm select-none"}`}>
                        {mockCode}
                      </span>
                    </span>
                    <button onClick={() => { setShowMock(!showMock); if (!showMock) setOtp(mockCode); }} className="text-amber-600 hover:text-amber-800 transition">
                      {showMock ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                    </button>
                  </div>
                )}

                <div>
                  <label className="block text-xs font-semibold text-stone-700 mb-2">
                    6-Digit OTP <span className="text-[#C85A32]">*</span>
                  </label>
                  <input
                    id="signup-otp"
                    type="text"
                    inputMode="numeric"
                    maxLength={6}
                    value={otp}
                    onChange={(e) => setOtp(e.target.value.replace(/\D/g, ""))}
                    onKeyDown={(e) => e.key === "Enter" && handleVerifyOtp()}
                    className="w-full px-4 py-3.5 rounded-xl border border-stone-200 focus:outline-none focus:ring-2 focus:ring-[#C85A32] text-stone-900 font-mono font-bold text-xl text-center tracking-[0.5em] transition"
                    placeholder="• • • • • •"
                  />
                </div>

                {error && <div className="bg-red-50 border border-red-200 text-red-700 text-xs rounded-xl px-4 py-3">{error}</div>}

                <button
                  id="signup-verify"
                  onClick={handleVerifyOtp}
                  disabled={loading}
                  className="w-full py-3.5 rounded-xl font-bold text-sm text-white transition-colors disabled:opacity-60 flex items-center justify-center gap-2"
                  style={{ backgroundColor: themeColor }}
                >
                  {loading ? (
                    <><RefreshCw className="w-4 h-4 animate-spin" /> Creating account…</>
                  ) : (
                    <><ShieldCheck className="w-4 h-4" /> Create Account & Sign In</>
                  )}
                </button>

                <div className="text-center">
                  {countdown > 0 ? (
                    <span className="text-xs text-stone-400">Resend in <span className="font-bold text-stone-600">{countdown}s</span></span>
                  ) : (
                    <button onClick={handleSendOtp} className="text-xs font-semibold text-[#C85A32] hover:underline">Resend OTP</button>
                  )}
                </div>
              </div>
            )}
          </div>
        </div>

        <p className="text-center text-xs text-stone-400 mt-6">
          By creating an account you agree to our{" "}
          <Link href="/" className="text-[#C85A32] hover:underline">Terms</Link> and{" "}
          <Link href="/" className="text-[#C85A32] hover:underline">Privacy Policy</Link>
        </p>
      </div>
    </div>
  );
}
