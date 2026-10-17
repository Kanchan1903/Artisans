import type { Metadata } from "next";
import "../globals.css";

export const metadata: Metadata = {
  title: "Sign In | KalaSathi",
  description: "Log in or create your KalaSathi account to start buying or selling handcrafted Indian arts.",
};

/**
 * Standalone layout for auth pages (/login, /signup).
 * Intentionally omits the global Navbar and Footer for a clean, focused auth experience.
 */
export default function AuthLayout({ children }: { children: React.ReactNode }) {
  return <>{children}</>;
}
