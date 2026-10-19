"use client";

import React, { createContext, useContext, useState, useEffect, useCallback } from "react";
import { API_BASE_URL } from "./api";

async function clearSessionCookie() {
  try {
    await fetch("/api/auth/session", { method: "DELETE" });
  } catch (_) {}
}

export type UserRole = "buyer" | "artisan" | "admin";

export interface AuthUser {
  user_id: number;
  name: string;
  phone: string;
  role: UserRole;
  language: string;
  artisan_id?: number | null;
  token: string;
}

interface AuthContextType {
  user: AuthUser | null;
  isLoading: boolean;
  isLoggedIn: boolean;
  isArtisan: boolean;
  isBuyer: boolean;
  token: string | null;
  sendOtp: (phone: string, role: UserRole) => Promise<{ mock_code?: string }>;
  verifyOtp: (phone: string, code: string, name?: string, role?: UserRole) => Promise<void>;
  refreshProfile: () => Promise<void>;
  updateUserName: (name: string) => void;
  logout: () => void;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);
const STORAGE_KEY = "kalasathi_auth";

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<AuthUser | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  // Restore session from localStorage
  useEffect(() => {
    try {
      const saved = localStorage.getItem(STORAGE_KEY);
      if (saved) {
        const parsed = JSON.parse(saved) as AuthUser;
        // Basic check: token must exist
        if (parsed.token && parsed.user_id) {
          setUser(parsed);
        }
      }
    } catch (_) {}
    setIsLoading(false);
  }, []);

  const sendOtp = useCallback(async (phone: string, role: UserRole) => {
    const res = await fetch(`${API_BASE_URL}/auth/otp/send`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ phone, role }),
    });
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.detail || "Failed to send OTP. Please try again.");
    }
    return res.json();
  }, []);

  const verifyOtp = useCallback(
    async (phone: string, code: string, name?: string, role: UserRole = "buyer") => {
      const res = await fetch(`${API_BASE_URL}/auth/otp/verify`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ phone, code, name, role }),
      });
      if (!res.ok) {
        const err = await res.json().catch(() => ({}));
        throw new Error(err.detail || "Invalid or expired OTP. Please try again.");
      }
      const data = await res.json();
      const authUser: AuthUser = {
        user_id: data.user_id,
        name: data.name || name || `User ${phone.slice(-4)}`,
        phone,
        role: (data.role as UserRole) || role,
        language: data.language || "en",
        artisan_id: data.artisan_id ?? null,
        token: data.access_token,
      };
      setUser(authUser);
      localStorage.setItem(STORAGE_KEY, JSON.stringify(authUser));
    },
    []
  );

  /**
   * Re-fetches the user profile from the backend and updates localStorage.
   * Use after profile updates.
   */
  const refreshProfile = useCallback(async () => {
    const current = user;
    if (!current?.token) return;
    try {
      const res = await fetch(`${API_BASE_URL}/auth/me`, {
        headers: { Authorization: `Bearer ${current.token}` },
        cache: "no-store",
      });
      if (res.ok) {
        const data = await res.json();
        const updated: AuthUser = {
          ...current,
          name: data.name || current.name,
        };
        setUser(updated);
        localStorage.setItem(STORAGE_KEY, JSON.stringify(updated));
      } else if (res.status === 401) {
        // Token expired — log out
        setUser(null);
        localStorage.removeItem(STORAGE_KEY);
      }
    } catch (_) {}
  }, [user]);

  /** Immediately update the display name without a round-trip. */
  const updateUserName = useCallback((name: string) => {
    setUser((prev) => {
      if (!prev) return prev;
      const updated = { ...prev, name };
      localStorage.setItem(STORAGE_KEY, JSON.stringify(updated));
      return updated;
    });
  }, []);

  const logout = useCallback(() => {
    setUser(null);
    localStorage.removeItem(STORAGE_KEY);
    clearSessionCookie(); // Clear HttpOnly cookie (Remember Me)
  }, []);

  return (
    <AuthContext.Provider
      value={{
        user,
        isLoading,
        isLoggedIn: !!user,
        isArtisan: user?.role === "artisan",
        isBuyer: user?.role === "buyer" || user?.role === "admin",
        token: user?.token ?? null,
        sendOtp,
        verifyOtp,
        refreshProfile,
        updateUserName,
        logout,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used within AuthProvider");
  return ctx;
}
