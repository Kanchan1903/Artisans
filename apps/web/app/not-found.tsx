import Link from "next/link";
import { Home, Search, ArrowLeft } from "lucide-react";

export default function NotFound() {
  return (
    <div className="min-h-screen bg-gradient-to-br from-[#FAF7F2] via-[#F5EFE5] to-[#EDE3D5] flex items-center justify-center px-4">
      <div className="text-center max-w-md">
        {/* Decorative artisan symbol */}
        <div className="w-24 h-24 rounded-3xl bg-[#C85A32] flex items-center justify-center mx-auto mb-6 shadow-xl shadow-[#C85A32]/25">
          <span className="text-white font-serif font-black text-5xl">क</span>
        </div>

        <h1 className="font-serif text-6xl font-black text-[#C85A32] mb-2">404</h1>
        <h2 className="font-serif text-2xl font-bold text-stone-900 mb-3">
          Page Not Found
        </h2>
        <p className="text-stone-500 text-sm leading-relaxed mb-8">
          This craft has wandered off to a distant village. The page you are looking for doesn&apos;t exist or has been moved.
        </p>

        <div className="flex flex-col sm:flex-row gap-3 justify-center">
          <Link
            href="/"
            className="inline-flex items-center justify-center gap-2 px-6 py-3 rounded-xl bg-[#C85A32] text-white font-semibold text-sm hover:bg-[#B34D28] transition"
          >
            <Home className="w-4 h-4" />
            Back to Home
          </Link>
          <Link
            href="/products"
            className="inline-flex items-center justify-center gap-2 px-6 py-3 rounded-xl bg-white border border-stone-200 text-stone-700 font-semibold text-sm hover:border-[#C85A32] hover:text-[#C85A32] transition"
          >
            <Search className="w-4 h-4" />
            Explore Catalog
          </Link>
        </div>
      </div>
    </div>
  );
}
