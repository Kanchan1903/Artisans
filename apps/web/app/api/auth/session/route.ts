/**
 * API Route: /api/auth/session
 * Manages the HttpOnly session cookie for token persistence.
 * 
 * POST: Set session token (with optional Remember Me duration)
 * DELETE: Clear session token (logout)
 */
import { NextRequest, NextResponse } from "next/server";

const COOKIE_NAME = "ks_token";

// 7 days for Remember Me, session cookie otherwise
const REMEMBER_MAX_AGE = 7 * 24 * 60 * 60; // seconds

export async function POST(request: NextRequest) {
  try {
    const { token, remember } = await request.json();

    if (!token || typeof token !== "string") {
      return NextResponse.json({ error: "Token required" }, { status: 400 });
    }

    const response = NextResponse.json({ ok: true });

    response.cookies.set(COOKIE_NAME, token, {
      httpOnly: true,
      secure: process.env.NODE_ENV === "production",
      sameSite: "lax",
      path: "/",
      // Only set maxAge for Remember Me — without it, cookie is session-only
      ...(remember ? { maxAge: REMEMBER_MAX_AGE } : {}),
    });

    return response;
  } catch {
    return NextResponse.json({ error: "Bad request" }, { status: 400 });
  }
}

export async function DELETE() {
  const response = NextResponse.json({ ok: true });
  response.cookies.set(COOKIE_NAME, "", {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
    maxAge: 0, // Immediately expire
  });
  return response;
}
