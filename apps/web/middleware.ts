/**
 * Next.js Middleware — Auth gate
 * 
 * Rules:
 * - Public routes (home, products browsing, artisan pages, cart): accessible without auth
 * - Protected routes (checkout, account, orders): require login
 * - Auth routes (login, signup): redirect to home if already logged in
 */
import { NextRequest, NextResponse } from "next/server";

// Routes that are always public — no auth required
const PUBLIC_PATHS = [
  "/",
  "/login",
  "/signup",
  "/products",  // public product browsing
  "/artisans",  // public artisan pages
  "/cart",      // public cart viewing
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
  "/orders",
];

// Auth-only routes (redirect away if already logged in)
const AUTH_ONLY_PATHS = ["/login", "/signup"];

function isPublic(pathname: string): boolean {
  if (pathname === "/") return true;
  return PUBLIC_PATHS.some((p) => pathname.startsWith(p));
}

function isProtected(pathname: string): boolean {
  return PROTECTED_PATHS.some((p) => pathname.startsWith(p));
}

function isAuthOnly(pathname: string): boolean {
  return AUTH_ONLY_PATHS.some((p) => pathname.startsWith(p));
}

function getToken(request: NextRequest): string | null {
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
