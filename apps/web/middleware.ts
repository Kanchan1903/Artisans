/**
 * Next.js Middleware — Auth-first gate
 * 
 * Rules:
 * - Public routes (products browsing, artisan pages): accessible without auth
 * - Protected routes (cart, checkout, account, orders): require login
 * - Auth routes (login, signup): redirect to home if already logged in
 * - All other routes: require login (login-first UX)
 */
import { NextRequest, NextResponse } from "next/server";

// Routes that are always public — no auth required
const PUBLIC_PATHS = [
  "/login",
  "/signup",
  "/products",  // public product browsing (SEO)
  "/artisans",  // public artisan pages (SEO)
  "/api/",
  "/_next/",
  "/favicon.ico",
  "/robots.txt",
  "/sitemap.xml",
];

// Routes that require authentication
const PROTECTED_PATHS = [
  "/account",
  "/checkout",
  "/cart",
  "/orders",
];

// Auth-only routes (redirect away if already logged in)
const AUTH_ONLY_PATHS = ["/login", "/signup"];

function isPublic(pathname: string): boolean {
  return PUBLIC_PATHS.some((p) => pathname.startsWith(p));
}

function isProtected(pathname: string): boolean {
  return PROTECTED_PATHS.some((p) => pathname.startsWith(p));
}

function isAuthOnly(pathname: string): boolean {
  return AUTH_ONLY_PATHS.some((p) => pathname.startsWith(p));
}

function getToken(request: NextRequest): string | null {
  // Check HttpOnly cookie first (secure, set by login)
  const cookieToken = request.cookies.get("ks_token")?.value;
  if (cookieToken) return cookieToken;
  return null;
}

export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;
  const token = getToken(request);
  const isLoggedIn = !!token;

  // If already logged in and on auth-only page → redirect to home
  if (isLoggedIn && isAuthOnly(pathname)) {
    return NextResponse.redirect(new URL("/", request.url));
  }

  // If trying to access a protected route without login → redirect to login
  if (!isLoggedIn && isProtected(pathname)) {
    const loginUrl = new URL("/login", request.url);
    loginUrl.searchParams.set("redirect", pathname);
    return NextResponse.redirect(loginUrl);
  }

  // For home page "/" — require login (login-first UX)
  if (!isLoggedIn && pathname === "/") {
    return NextResponse.redirect(new URL("/login", request.url));
  }

  return NextResponse.next();
}

export const config = {
  matcher: [
    /*
     * Match all request paths except static files
     */
    "/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)",
  ],
};
