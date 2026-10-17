"use client";

import React, { createContext, useContext, useState, useEffect, useCallback } from "react";
import { API_BASE_URL } from "./api";

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
  sendOtp: (phone: string, role: UserRole) => Promise<{ mock_code?: string }>;
  verifyOtp: (phone: string, code: string, name?: string, role?: UserRole) => Promise<void>;
  logout: () => void;
  token: string | null;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

const STORAGE_KEY = "kalasathi_auth";

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<AuthUser | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    try {
      const saved = localStorage.getItem(STORAGE_KEY);
      if (saved) {
        setUser(JSON.parse(saved));
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
      throw new Error(err.detail || "Failed to send OTP");
    }
    return res.json();
  }, []);

  const verifyOtp = useCallback(
    async (phone: string, code: string, name?: string, role?: UserRole) => {
      const res = await fetch(`${API_BASE_URL}/auth/otp/verify`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ phone, code, name, role }),
      });
      if (!res.ok) {
        const err = await res.json().catch(() => ({}));
        throw new Error(err.detail || "Invalid OTP");
      }
      const data = await res.json();
      const authUser: AuthUser = {
        user_id: data.user_id,
        name: data.name,
        phone,
        role: data.role as UserRole,
        language: data.language || "en",
        artisan_id: data.artisan_id,
        token: data.access_token,
      };
      setUser(authUser);
      localStorage.setItem(STORAGE_KEY, JSON.stringify(authUser));
    },
    []
  );

  const logout = useCallback(() => {
    setUser(null);
    localStorage.removeItem(STORAGE_KEY);
  }, []);

  return (
    <AuthContext.Provider
      value={{
        user,
        isLoading,
        isLoggedIn: !!user,
        isArtisan: user?.role === "artisan",
        isBuyer: user?.role === "buyer",
        sendOtp,
        verifyOtp,
        logout,
        token: user?.token ?? null,
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
