import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Create Account | KalaSathi",
  description: "Join KalaSathi as a buyer or artisan and connect with India's finest handcraft tradition.",
};

export default function SignupLayout({ children }: { children: React.ReactNode }) {
  return <>{children}</>;
}
