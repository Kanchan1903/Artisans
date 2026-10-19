"use client";

import React, { useState, useEffect, Suspense } from "react";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import {
  Eye, EyeOff, Lock, User, Mail, Phone,
  Loader2, CheckCircle, ShieldCheck, Sparkles, ArrowRight,
  Globe, ChevronDown,
} from "lucide-react";
import { useAuth } from "@/lib/auth-context";
import { useLanguage } from "@/lib/language-context";

async function persistTokenCookie(token: string, remember: boolean) {
  try {
    await fetch("/api/auth/session", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ token, remember }),
    });
  } catch (_) {}
}

function LoginContent() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const redirectTo = searchParams.get("redirect") || "/";
  const { isLoggedIn, isLoading, loginWithPassword, registerWithPassword, token } = useAuth();
  const { locale, setLocale, t, languages } = useLanguage();

  const [tab, setTab] = useState<"signin" | "signup">("signin");
  const [showLangMenu, setShowLangMenu] = useState(false);

  // Sign In fields
  const [identifier, setIdentifier] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);

  // Sign Up fields
  const [name, setName] = useState("");
  const [phone, setPhone] = useState("");
  const [email, setEmail] = useState("");
  const [signupPassword, setSignupPassword] = useState("");
  const [showSignupPassword, setShowSignupPassword] = useState(false);

  // Remember Me checkbox — unchecked by default
  const [rememberMe, setRememberMe] = useState(false);

  // UI state
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");

  // Redirect if already logged in
  useEffect(() => {
    if (!isLoading && isLoggedIn && token) {
      persistTokenCookie(token, true).then(() => {
        router.replace(redirectTo);
      });
    }
  }, [isLoggedIn, isLoading, token, redirectTo, router]);

  const handleSignIn = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    if (!identifier.trim()) {
      setError("Please enter your name, email, or phone.");
      return;
    }
    if (!password) {
      setError("Please enter your password.");
      return;
    }

    setSubmitting(true);
    try {
      await loginWithPassword(identifier.trim(), password);
      const stored = localStorage.getItem("kalasathi_auth");
      if (stored) {
        const auth = JSON.parse(stored);
        await persistTokenCookie(auth.token, rememberMe);
      }
      router.replace(redirectTo);
    } catch (err: any) {
      setError(err.message || "Invalid credentials. Please check your details.");
    } finally {
      setSubmitting(false);
    }
  };

  const handleSignUp = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    if (!name.trim()) {
      setError("Please enter your full name.");
      return;
    }
    const cleanPhone = phone.replace(/\D/g, "");
    if (cleanPhone.length < 10) {
      setError("Please enter a valid 10-digit mobile number.");
      return;
    }
    if (signupPassword.length < 6) {
      setError("Password must be at least 6 characters.");
      return;
    }

    setSubmitting(true);
    try {
      const fullPhone = cleanPhone.startsWith("91") && cleanPhone.length > 10 ? `+${cleanPhone}` : `+91${cleanPhone.slice(-10)}`;
      await registerWithPassword(name.trim(), fullPhone, signupPassword, email.trim() || undefined);
      setSuccess("Account created successfully!");
      const stored = localStorage.getItem("kalasathi_auth");
      if (stored) {
        const auth = JSON.parse(stored);
        await persistTokenCookie(auth.token, rememberMe);
      }
      setTimeout(() => router.replace(redirectTo), 600);
    } catch (err: any) {
      setError(err.message || "Registration failed. Please check your details.");
    } finally {
      setSubmitting(false);
    }
  };

  const activeLang = languages.find((l) => l.code === locale) || languages[0];

  if (isLoading) {
    return (
      <div className="min-h-screen bg-[#FAF7F2] flex items-center justify-center">
        <Loader2 className="w-8 h-8 animate-spin text-[#C85A32]" />
      </div>
    );
  }

  return (
    <div className="relative min-h-screen bg-gradient-to-br from-[#FAF7F2] via-[#F3EFE6] to-[#EAE2D6] flex flex-col justify-center py-12 sm:px-6 lg:px-8">
      {/* 12-Language Switcher floating in top-right */}
      <div className="absolute top-5 right-5 z-20">
        <div className="relative">
          <button
            type="button"
            onClick={() => setShowLangMenu(!showLangMenu)}
            className="flex items-center gap-1.5 bg-white/90 backdrop-blur-md border border-[#E5DDD0] rounded-full px-3.5 py-1.5 text-xs font-semibold text-[#262220] hover:border-[#C85A32] shadow-sm transition"
            title="Change Language / भाषा बदलें"
          >
            <Globe className="w-3.5 h-3.5 text-[#2C3E6B]" />
            <span>{activeLang.native}</span>
            <ChevronDown className={`w-3 h-3 text-stone-400 transition-transform ${showLangMenu ? "rotate-180" : ""}`} />
          </button>

          {showLangMenu && (
            <>
              <div className="fixed inset-0 z-40" onClick={() => setShowLangMenu(false)} />
              <div className="absolute right-0 top-full mt-2 w-56 bg-white rounded-2xl shadow-2xl border border-stone-200 overflow-hidden z-50 py-2 max-h-80 overflow-y-auto">
                <div className="px-3 py-1.5 text-[10px] uppercase font-bold text-stone-400 tracking-wider border-b border-stone-100">
                  Select Language (12 Indian Languages)
                </div>
                {languages.map((lang) => (
                  <button
                    key={lang.code}
                    type="button"
                    onClick={() => {
                      setLocale(lang.code);
                      setShowLangMenu(false);
                    }}
                    className={`w-full px-4 py-2 text-left text-xs flex items-center justify-between hover:bg-[#FBECE6] transition ${
                      locale === lang.code ? "bg-[#FBECE6]/60 text-[#C85A32] font-bold" : "text-stone-700"
                    }`}
                  >
                    <span className="text-sm font-medium">{lang.native}</span>
                    <span className="text-[11px] text-stone-400 font-sans">{lang.name}</span>
                  </button>
                ))}
              </div>
            </>
          )}
        </div>
      </div>

      <div className="sm:mx-auto sm:w-full sm:max-w-md">
        {/* Brand */}
        <div className="text-center mb-6">
          <Link href="/" className="inline-flex flex-col items-center gap-2">
            <div className="w-14 h-14 rounded-2xl bg-[#C85A32] flex items-center justify-center shadow-lg">
              <span className="text-white font-black text-2xl font-serif">क</span>
            </div>
            <div>
              <span className="font-black text-2xl text-[#262220] font-serif">KalaSathi</span>
              <p className="text-xs text-[#6B645F] font-medium tracking-wider uppercase">कलासाथी • Handicrafts</p>
            </div>
          </Link>
          <p className="text-[#6B645F] text-sm mt-3">
            Handcrafted treasures of Bharat, direct from village artisans
          </p>
        </div>

        {/* Card */}
        <div className="bg-white rounded-3xl shadow-xl border border-[#E5DDD0] overflow-hidden">
          {/* Tabs */}
          <div className="grid grid-cols-2 border-b border-[#E5DDD0]">
            <button
              type="button"
              onClick={() => { setTab("signin"); setError(""); setSuccess(""); }}
              className={`py-4 text-sm font-bold transition-colors ${
                tab === "signin"
                  ? "text-[#C85A32] border-b-2 border-[#C85A32] bg-[#FBECE6]/40"
                  : "text-stone-500 hover:text-stone-700"
              }`}
            >
              {t("signIn", "Sign In")}
            </button>
            <button
              type="button"
              onClick={() => { setTab("signup"); setError(""); setSuccess(""); }}
              className={`py-4 text-sm font-bold transition-colors ${
                tab === "signup"
                  ? "text-[#C85A32] border-b-2 border-[#C85A32] bg-[#FBECE6]/40"
                  : "text-stone-500 hover:text-stone-700"
              }`}
            >
              {t("createAccount", "Create Account")}
            </button>
          </div>

          <div className="p-7">
            {/* SIGN IN FORM */}
            {tab === "signin" && (
              <form onSubmit={handleSignIn} className="space-y-4">
                <div>
                  <h2 className="font-serif text-xl font-bold text-stone-900">{t("welcomeBack", "Welcome Back")}</h2>
                  <p className="text-stone-500 text-xs mt-1">{t("welcomeBackSub", "Sign in with your name, email, or mobile number")}</p>
                </div>

                {/* Name / Email / Phone */}
                <div>
                  <label className="block text-xs font-semibold text-stone-700 mb-1.5">
                    {t("nameEmailPhone", "Name / Email / Mobile Number")}
                  </label>
                  <div className="relative">
                    <User className="w-4 h-4 text-stone-400 absolute left-3.5 top-1/2 -translate-y-1/2 pointer-events-none" />
                    <input
                      type="text"
                      value={identifier}
                      onChange={(e) => setIdentifier(e.target.value)}
                      placeholder="e.g. Priya Sharma or priya@example.com"
                      autoComplete="username"
                      required
                      className="w-full pl-10 pr-4 py-3 rounded-xl border border-stone-200 bg-stone-50 text-stone-900 text-sm focus:outline-none focus:ring-2 focus:ring-[#C85A32] focus:border-transparent"
                    />
                  </div>
                </div>

                {/* Password */}
                <div>
                  <div className="flex items-center justify-between mb-1.5">
                    <label className="block text-xs font-semibold text-stone-700">
                      {t("password", "Password")}
                    </label>
                  </div>
                  <div className="relative">
                    <Lock className="w-4 h-4 text-stone-400 absolute left-3.5 top-1/2 -translate-y-1/2 pointer-events-none" />
                    <input
                      type={showPassword ? "text" : "password"}
                      value={password}
                      onChange={(e) => setPassword(e.target.value)}
                      placeholder="••••••••"
                      autoComplete="current-password"
                      required
                      className="w-full pl-10 pr-11 py-3 rounded-xl border border-stone-200 bg-stone-50 text-stone-900 text-sm focus:outline-none focus:ring-2 focus:ring-[#C85A32] focus:border-transparent"
                    />
                    <button
                      type="button"
                      onClick={() => setShowPassword(!showPassword)}
                      className="absolute right-3.5 top-1/2 -translate-y-1/2 text-stone-400 hover:text-stone-600 focus:outline-none"
                    >
                      {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                    </button>
                  </div>
                </div>

                {/* Remember Me */}
                <label className="flex items-center gap-2.5 cursor-pointer pt-1">
                  <input
                    type="checkbox"
                    checked={rememberMe}
                    onChange={(e) => setRememberMe(e.target.checked)}
                    className="w-4 h-4 accent-[#C85A32] rounded cursor-pointer"
                  />
                  <span className="text-xs text-stone-600 font-medium select-none">
                    {t("rememberMe", "Remember me on this browser")}
                  </span>
                </label>

                {error && (
                  <div className="p-3 bg-red-50 border border-red-200 rounded-xl text-xs text-red-700">
                    ⚠ {error}
                  </div>
                )}

                <button
                  type="submit"
                  disabled={submitting}
                  className="w-full py-3.5 px-6 bg-[#C85A32] text-white font-bold rounded-xl flex items-center justify-center gap-2 hover:bg-[#B34D28] disabled:opacity-60 disabled:cursor-not-allowed transition shadow-md shadow-[#C85A32]/20 text-sm"
                >
                  {submitting ? (
                    <><Loader2 className="w-4 h-4 animate-spin" /> {t("signIn", "Sign In")}...</>
                  ) : (
                    <>{t("signIn", "Sign In")} <ArrowRight className="w-4 h-4" /></>
                  )}
                </button>
              </form>
            )}

            {/* SIGN UP FORM */}
            {tab === "signup" && (
              <form onSubmit={handleSignUp} className="space-y-4">
                <div>
                  <h2 className="font-serif text-xl font-bold text-stone-900">{t("createAccount", "Create an Account")}</h2>
                  <p className="text-stone-500 text-xs mt-1">Join as a buyer to shop authentic handmade crafts</p>
                </div>

                {/* Full Name */}
                <div>
                  <label className="block text-xs font-semibold text-stone-700 mb-1.5">
                    {t("fullName", "Full Name")} <span className="text-red-500">*</span>
                  </label>
                  <div className="relative">
                    <User className="w-4 h-4 text-stone-400 absolute left-3.5 top-1/2 -translate-y-1/2 pointer-events-none" />
                    <input
                      type="text"
                      value={name}
                      onChange={(e) => setName(e.target.value)}
                      placeholder="e.g. Priya Sharma"
                      autoComplete="name"
                      required
                      className="w-full pl-10 pr-4 py-3 rounded-xl border border-stone-200 bg-stone-50 text-stone-900 text-sm focus:outline-none focus:ring-2 focus:ring-[#C85A32] focus:border-transparent"
                    />
                  </div>
                </div>

                {/* Mobile Number */}
                <div>
                  <label className="block text-xs font-semibold text-stone-700 mb-1.5">
                    {t("phone", "Mobile Number")} <span className="text-red-500">*</span>
                  </label>
                  <div className="relative">
                    <Phone className="w-4 h-4 text-stone-400 absolute left-3.5 top-1/2 -translate-y-1/2 pointer-events-none" />
                    <input
                      type="tel"
                      value={phone}
                      onChange={(e) => setPhone(e.target.value.replace(/\D/g, "").slice(0, 10))}
                      placeholder="98765 43210"
                      maxLength={10}
                      autoComplete="tel"
                      required
                      className="w-full pl-10 pr-4 py-3 rounded-xl border border-stone-200 bg-stone-50 text-stone-900 text-sm focus:outline-none focus:ring-2 focus:ring-[#C85A32] focus:border-transparent"
                    />
                  </div>
                </div>

                {/* Email (optional) */}
                <div>
                  <label className="block text-xs font-semibold text-stone-700 mb-1.5">
                    {t("email", "Email Address (Optional)")}
                  </label>
                  <div className="relative">
                    <Mail className="w-4 h-4 text-stone-400 absolute left-3.5 top-1/2 -translate-y-1/2 pointer-events-none" />
                    <input
                      type="email"
                      value={email}
                      onChange={(e) => setEmail(e.target.value)}
                      placeholder="priya@example.com"
                      autoComplete="email"
                      className="w-full pl-10 pr-4 py-3 rounded-xl border border-stone-200 bg-stone-50 text-stone-900 text-sm focus:outline-none focus:ring-2 focus:ring-[#C85A32] focus:border-transparent"
                    />
                  </div>
                </div>

                {/* Password */}
                <div>
                  <label className="block text-xs font-semibold text-stone-700 mb-1.5">
                    {t("password", "Password")} <span className="text-red-500">*</span>
                  </label>
                  <div className="relative">
                    <Lock className="w-4 h-4 text-stone-400 absolute left-3.5 top-1/2 -translate-y-1/2 pointer-events-none" />
                    <input
                      type={showSignupPassword ? "text" : "password"}
                      value={signupPassword}
                      onChange={(e) => setSignupPassword(e.target.value)}
                      placeholder="Minimum 6 characters"
                      autoComplete="new-password"
                      required
                      minLength={6}
                      className="w-full pl-10 pr-11 py-3 rounded-xl border border-stone-200 bg-stone-50 text-stone-900 text-sm focus:outline-none focus:ring-2 focus:ring-[#C85A32] focus:border-transparent"
                    />
                    <button
                      type="button"
                      onClick={() => setShowSignupPassword(!showSignupPassword)}
                      className="absolute right-3.5 top-1/2 -translate-y-1/2 text-stone-400 hover:text-stone-600 focus:outline-none"
                    >
                      {showSignupPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                    </button>
                  </div>
                </div>

                {/* Remember Me */}
                <label className="flex items-center gap-2.5 cursor-pointer pt-1">
                  <input
                    type="checkbox"
                    checked={rememberMe}
                    onChange={(e) => setRememberMe(e.target.checked)}
                    className="w-4 h-4 accent-[#C85A32] rounded cursor-pointer"
                  />
                  <span className="text-xs text-stone-600 font-medium select-none">
                    {t("rememberMe", "Remember me on this browser")}
                  </span>
                </label>

                {error && (
                  <div className="p-3 bg-red-50 border border-red-200 rounded-xl text-xs text-red-700">
                    ⚠ {error}
                  </div>
                )}

                {success && (
                  <div className="p-3 bg-emerald-50 border border-emerald-200 rounded-xl text-xs text-emerald-700 flex items-center gap-2">
                    <CheckCircle className="w-4 h-4" /> {success}
                  </div>
                )}

                <button
                  type="submit"
                  disabled={submitting}
                  className="w-full py-3.5 px-6 bg-[#C85A32] text-white font-bold rounded-xl flex items-center justify-center gap-2 hover:bg-[#B34D28] disabled:opacity-60 disabled:cursor-not-allowed transition shadow-md shadow-[#C85A32]/20 text-sm"
                >
                  {submitting ? (
                    <><Loader2 className="w-4 h-4 animate-spin" /> {t("createAccount", "Creating Account")}...</>
                  ) : (
                    <>{t("createAccount", "Create Buyer Account")} <ArrowRight className="w-4 h-4" /></>
                  )}
                </button>
              </form>
            )}

            {/* Artisan App Note */}
            <div className="mt-6 pt-5 border-t border-stone-100">
              <div className="flex items-start gap-3 p-3 bg-[#FAF7F2] rounded-xl border border-[#E5DDD0]">
                <Sparkles className="w-4 h-4 text-[#E09F3E] flex-shrink-0 mt-0.5" />
                <div>
                  <p className="text-xs text-stone-700 font-semibold">Are you an artisan?</p>
                  <p className="text-[11px] text-stone-500 mt-0.5 leading-relaxed">
                    Download the <strong className="text-stone-700">KalaSathi Mobile App</strong> to list your crafts using voice in your dialect. The website is exclusively for buyers.
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Badges */}
        <div className="flex items-center justify-center gap-6 mt-6 text-xs text-stone-400">
          <div className="flex items-center gap-1.5">
            <ShieldCheck className="w-3.5 h-3.5 text-emerald-500" />
            <span>Encrypted Passwords</span>
          </div>
          <div className="flex items-center gap-1.5">
            <span>🇮🇳</span>
            <span>Direct to Artisans</span>
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
