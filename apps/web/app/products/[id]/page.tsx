"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import {
  Sparkles,
  MapPin,
  ShieldCheck,
  Globe2,
  ShoppingCart,
  Zap,
  Package,
  Award,
  Clock,
  Heart,
  Share2,
  CheckCircle2,
  MessageSquare,
  Send,
  Star,
  ChevronRight,
  Info,
} from "lucide-react";
import {
  fetchProductById,
  Product,
  ProductTranslation,
  submitB2BInquiry,
} from "@/lib/api";
import { useCart } from "@/lib/cart-context";

const LANGUAGES_12 = [
  { code: "en", name: "English", native: "English" },
  { code: "hi", name: "Hindi", native: "हिन्दी" },
  { code: "mr", name: "Marathi", native: "मराठी" },
  { code: "bn", name: "Bengali", native: "বাংলা" },
  { code: "ta", name: "Tamil", native: "தமிழ்" },
  { code: "te", name: "Telugu", native: "తెలుగు" },
  { code: "kn", name: "Kannada", native: "ಕನ್ನಡ" },
  { code: "ml", name: "Malayalam", native: "മലയാളം" },
  { code: "gu", name: "Gujarati", native: "ગુજરાતી" },
  { code: "pa", name: "Punjabi", native: "ਪੰਜਾਬੀ" },
  { code: "or", name: "Odia", native: "ଓଡ଼ିଆ" },
  { code: "as", name: "Assamese", native: "অসমীয়া" },
];

export default function ProductDetailPage({ params }: { params: { id: string } }) {
  const router = useRouter();
  const productId = Number(params.id);

  const [product, setProduct] = useState<Product | null>(null);
  const [selectedLanguage, setSelectedLanguage] = useState<string>("en");
  const [selectedImageIdx, setSelectedImageIdx] = useState<number>(0);
  const [quantity, setQuantity] = useState<number>(1);
  const [isWishlisted, setIsWishlisted] = useState<boolean>(false);
  const [showInquiryModal, setShowInquiryModal] = useState<boolean>(false);

  // B2B Inquiry form state
  const [inquiryName, setInquiryName] = useState("");
  const [inquiryEmail, setInquiryEmail] = useState("");
  const [inquiryQty, setInquiryQty] = useState(25);
  const [inquiryMsg, setInquiryMsg] = useState("");
  const [inquirySuccess, setInquirySuccess] = useState(false);
  const [inquiryLoading, setInquiryLoading] = useState(false);

  // Reviews state
  const [reviewsList, setReviewsList] = useState([
    {
      name: "Priya Sharma, Mumbai",
      tag: "Verified Buyer",
      rating: 5,
      comment: "The finish on this authentic craft is breathtaking. You can feel the earthen authenticity and precision that mass-produced factory decor could never mimic. Proud to support our artisans!",
    },
    {
      name: "Arun Kumar, Bengaluru",
      tag: "Verified Buyer",
      rating: 5,
      comment: "Packaging was secure and eco-friendly. Reading the artisan’s story in the regional language card included with the package made this special.",
    },
  ]);
  const [showReviewModal, setShowReviewModal] = useState(false);
  const [newReviewName, setNewReviewName] = useState("");
  const [newReviewCity, setNewReviewCity] = useState("");
  const [newReviewRating, setNewReviewRating] = useState(5);
  const [newReviewComment, setNewReviewComment] = useState("");

  const handleReviewSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newReviewName.trim() || !newReviewComment.trim()) return;
    setReviewsList([
      {
        name: `${newReviewName.trim()}, ${newReviewCity.trim() || "India"}`,
        tag: "Verified Buyer",
        rating: newReviewRating,
        comment: newReviewComment.trim(),
      },
      ...reviewsList,
    ]);
    setShowReviewModal(false);
    setNewReviewName("");
    setNewReviewCity("");
    setNewReviewComment("");
  };

  const { addToCart } = useCart();
  const [addedNotice, setAddedNotice] = useState(false);

  const [notFound, setNotFound] = useState(false);

  useEffect(() => {
    async function loadProduct() {
      try {
        const p = await fetchProductById(productId);
        if (p) {
          setProduct(p);
        } else {
          setNotFound(true);
        }
      } catch (_) {
        setNotFound(true);
      }
    }
    loadProduct();
  }, [productId]);

  if (notFound) {
    return (
      <div className="min-h-screen bg-[#FAF7F2] flex flex-col items-center justify-center p-6 text-center">
        <h2 className="font-serif text-2xl font-bold text-stone-900 mb-2">Product Not Found</h2>
        <p className="text-stone-500 text-sm max-w-sm mb-6">
          This handcrafted creation may have been sold out, unpublished, or does not exist.
        </p>
        <Link
          href="/products"
          className="px-6 py-2.5 bg-[#C85A32] text-white rounded-xl text-sm font-semibold hover:bg-[#B34D28] transition"
        >
          Explore Other Crafts
        </Link>
      </div>
    );
  }

  if (!product) {
    return (
      <div className="min-h-screen bg-[#FAF7F2] flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-4 border-[#C85A32] border-t-transparent"></div>
      </div>
    );
  }

  // Find translation for selected language, fallback to English or Hindi
  const activeTranslation: ProductTranslation | undefined =
    product.translations?.find((t) => t.language === selectedLanguage) ||
    product.translations?.find((t) => t.language === "en") || {
      id: 0,
      language: "en",
      title: product.title_en,
      description: product.description_en || "",
    };

  const currentTitle =
    selectedLanguage === "en"
      ? product.title_en
      : selectedLanguage === "hi" && product.title_hi
      ? product.title_hi
      : activeTranslation?.title || product.title_en;

  const currentDescription =
    selectedLanguage === "en"
      ? product.description_en
      : selectedLanguage === "hi" && product.description_hi
      ? product.description_hi
      : activeTranslation?.description || product.description_en;

  const primaryImage =
    product.images?.[selectedImageIdx]?.url ||
    product.images?.[0]?.url ||
    "https://images.unsplash.com/photo-1582562124811-c09040d0a901?w=800";

  const handleAddToCart = () => {
    addToCart(product, quantity);
    setAddedNotice(true);
    setTimeout(() => setAddedNotice(false), 2000);
  };

  const handleBuyNow = () => {
    addToCart(product, quantity);
    router.push("/checkout");
  };

  const handleB2BSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setInquiryLoading(true);
    try {
      await submitB2BInquiry({
        product_id: product.id,
        buyer_name: inquiryName,
        buyer_email: inquiryEmail,
        quantity_needed: inquiryQty,
        message: inquiryMsg,
      });
      setInquirySuccess(true);
      setTimeout(() => {
        setInquirySuccess(false);
        setShowInquiryModal(false);
      }, 2500);
    } catch (err) {
      alert("Failed to submit inquiry. Please try again.");
    } finally {
      setInquiryLoading(false);
    }
  };

  // Structured Data JSON-LD for Google Rich Results
  const jsonLd = {
    "@context": "https://schema.org/",
    "@type": "Product",
    name: product.title_en,
    image: [primaryImage],
    description: product.description_en,
    sku: `KS-PROD-${product.id}`,
    brand: {
      "@type": "Brand",
      name: "KalaSathi Artisan Collective",
    },
    offers: {
      "@type": "Offer",
      url: `https://kalasathi.bharat/products/${product.id}`,
      priceCurrency: "INR",
      price: product.price,
      availability: product.stock > 0 ? "https://schema.org/InStock" : "https://schema.org/OutOfStock",
      seller: {
        "@type": "Person",
        name: product.artisan?.name,
      },
    },
  };

  return (
    <div className="min-h-screen bg-[#FAF7F2] py-8 px-4 sm:px-6 lg:px-8">
      {/* JSON-LD Script tag */}
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
      />

      <div className="max-w-7xl mx-auto">
        {/* Breadcrumb */}
        <nav className="flex items-center space-x-2 text-xs text-stone-500 mb-6">
          <Link href="/" className="hover:text-[#C85A32]">Home</Link>
          <ChevronRight className="w-3 h-3 text-stone-400" />
          <Link href="/products" className="hover:text-[#C85A32]">Crafts</Link>
          <ChevronRight className="w-3 h-3 text-stone-400" />
          <span className="text-stone-800 font-medium truncate max-w-[200px] sm:max-w-xs">
            {product.title_en}
          </span>
        </nav>

        {/* Main Product Layout */}
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-10 bg-white p-6 sm:p-10 rounded-3xl border border-stone-200/80 shadow-sm">
          
          {/* Left Column: Image Studio Gallery (5 cols) */}
          <div className="lg:col-span-5 space-y-4">
            <div className="relative aspect-square w-full rounded-2xl overflow-hidden bg-stone-100 border border-stone-200">
              <img
                src={primaryImage}
                alt={currentTitle}
                className="w-full h-full object-cover"
              />
              {product.ai_generated && (
                <div className="absolute top-4 left-4 inline-flex items-center space-x-1.5 bg-white/95 backdrop-blur-md px-3 py-1.5 rounded-full text-xs font-semibold text-stone-800 shadow-sm border border-stone-100">
                  <Sparkles className="w-3.5 h-3.5 text-[#E09F3E]" />
                  <span>AI Studio Enhanced (1:1)</span>
                </div>
              )}
              <button
                onClick={() => setIsWishlisted(!isWishlisted)}
                className="absolute top-4 right-4 p-2.5 rounded-full bg-white/90 backdrop-blur-sm text-stone-700 hover:text-rose-600 shadow-sm transition-colors"
                title="Save to Wishlist"
              >
                <Heart
                  className={`w-4 h-4 ${
                    isWishlisted ? "fill-rose-500 text-rose-500" : ""
                  }`}
                />
              </button>
            </div>

            {/* Thumbnails */}
            {product.images && product.images.length > 1 && (
              <div className="flex gap-3 overflow-x-auto pb-2">
                {product.images.map((img, idx) => (
                  <button
                    key={img.id}
                    onClick={() => setSelectedImageIdx(idx)}
                    className={`relative w-20 h-20 rounded-xl overflow-hidden border-2 transition-all flex-shrink-0 ${
                      selectedImageIdx === idx
                        ? "border-[#C85A32] shadow-sm"
                        : "border-stone-200 hover:border-stone-300"
                    }`}
                  >
                    <img
                      src={img.url}
                      alt="Thumbnail"
                      className="w-full h-full object-cover"
                    />
                  </button>
                ))}
              </div>
            )}

            {/* Artisan Trust Badge */}
            <div className="mt-6 p-4 rounded-2xl bg-[#FAF7F2] border border-stone-200">
              <div className="flex items-center space-x-3">
                <ShieldCheck className="w-6 h-6 text-emerald-600 flex-shrink-0" />
                <div>
                  <h4 className="text-sm font-bold text-stone-900">Direct From Village Artisan</h4>
                  <p className="text-xs text-stone-500">
                    No middlemen. 92% of the purchase proceeds go straight to the artisan’s bank account.
                  </p>
                </div>
              </div>
            </div>
          </div>

          {/* Right Column: Information, 12-Language Switcher, Actions (7 cols) */}
          <div className="lg:col-span-7 flex flex-col justify-between space-y-6">
            <div>
              {/* Category & Origin Tags */}
              <div className="flex flex-wrap items-center gap-2 mb-2">
                <span className="px-2.5 py-1 bg-[#2C3E6B]/10 text-[#2C3E6B] rounded-lg text-xs font-semibold">
                  {product.artisan?.craft_type || "Folk Heritage"}
                </span>
                <span className="inline-flex items-center space-x-1 px-2.5 py-1 bg-stone-100 text-stone-700 rounded-lg text-xs font-medium">
                  <MapPin className="w-3 h-3 text-[#C85A32]" />
                  <span>
                    {product.artisan?.village}, {product.artisan?.state}
                  </span>
                </span>
                <span className="px-2.5 py-1 bg-emerald-50 text-emerald-700 rounded-lg text-xs font-medium flex items-center space-x-1">
                  <Award className="w-3 h-3 text-emerald-600" />
                  <span>GI Certified Tradition</span>
                </span>
              </div>

              {/* Product Title */}
              <h1 className="font-serif text-2xl sm:text-3xl font-bold text-stone-900 leading-tight mb-3">
                {currentTitle}
              </h1>

              {/* Price & Stock */}
              <div className="flex items-baseline space-x-4 mb-6">
                <span className="text-3xl font-extrabold text-stone-900">
                  ₹{product.price.toLocaleString("en-IN")}
                </span>
                <span className="text-xs text-stone-500 font-medium line-through">
                  ₹{Math.round(product.price * 1.35).toLocaleString("en-IN")}
                </span>
                <span className="text-xs font-bold text-emerald-700 bg-emerald-100/70 px-2 py-0.5 rounded">
                  Fair Price Guarantee
                </span>
                {product.stock > 0 ? (
                  <span className="text-xs text-emerald-600 font-medium ml-auto flex items-center space-x-1">
                    <CheckCircle2 className="w-3.5 h-3.5" />
                    <span>In Stock ({product.stock} left)</span>
                  </span>
                ) : (
                  <span className="text-xs text-rose-600 font-medium ml-auto">
                    Crafting in progress (Out of stock)
                  </span>
                )}
              </div>

              {/* 12 LANGUAGES TRANSLATION SWITCHER */}
              <div className="mb-6 p-4 bg-stone-50/80 rounded-2xl border border-stone-200">
                <div className="flex items-center justify-between mb-2">
                  <div className="flex items-center space-x-2 text-xs font-bold uppercase tracking-wider text-stone-600">
                    <Globe2 className="w-4 h-4 text-[#C85A32]" />
                    <span>Read in 12 Indian Languages</span>
                  </div>
                  <span className="text-[11px] text-stone-400 font-normal">
                    AI Multimodal Voice Translation
                  </span>
                </div>
                <div className="flex flex-wrap gap-1.5">
                  {LANGUAGES_12.map((lang) => (
                    <button
                      key={lang.code}
                      onClick={() => setSelectedLanguage(lang.code)}
                      className={`px-2.5 py-1 text-xs rounded-lg font-medium transition-all ${
                        selectedLanguage === lang.code
                          ? "bg-[#C85A32] text-white shadow-sm"
                          : "bg-white text-stone-700 border border-stone-200 hover:border-stone-300"
                      }`}
                    >
                      {lang.native} <span className="text-[10px] opacity-75">({lang.name})</span>
                    </button>
                  ))}
                </div>
              </div>

              {/* Description */}
              <div className="prose prose-stone max-w-none text-stone-700 text-sm leading-relaxed mb-6">
                <p>{currentDescription}</p>
              </div>

              {/* Craft Specifications */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 mb-6 p-4 bg-[#FAF7F2] rounded-2xl border border-stone-200/80 text-xs">
                <div>
                  <span className="font-semibold text-stone-500 block mb-0.5">Primary Materials:</span>
                  <span className="font-medium text-stone-800">
                    {product.material || "Organic natural materials"}
                  </span>
                </div>
                <div>
                  <span className="font-semibold text-stone-500 block mb-0.5">Heritage Technique:</span>
                  <span className="font-medium text-stone-800">
                    {product.technique || "Handcrafted by lineage technique"}
                  </span>
                </div>
                <div className="sm:col-span-2">
                  <span className="font-semibold text-stone-500 block mb-0.5">Care Instructions:</span>
                  <span className="font-medium text-stone-800">
                    {product.care_instructions || "Handle gently with clean dry cloth"}
                  </span>
                </div>
                {product.voice_transcript && (
                  <div className="sm:col-span-2 pt-2 border-t border-stone-200">
                    <span className="font-semibold text-stone-500 block mb-0.5">
                      Artisan’s Voice Note:
                    </span>
                    <span className="italic text-stone-600">
                      &quot;{product.voice_transcript}&quot;
                    </span>
                  </div>
                )}
              </div>
            </div>

            {/* Actions: Quantity + Add to Cart + Buy Now + B2B Wholesale */}
            <div className="pt-4 border-t border-stone-200 space-y-4">
              <div className="flex flex-col sm:flex-row items-center gap-3">
                {/* Quantity */}
                <div className="flex items-center border border-stone-300 rounded-xl bg-white p-1">
                  <button
                    onClick={() => setQuantity(Math.max(1, quantity - 1))}
                    className="w-8 h-8 flex items-center justify-center text-stone-600 hover:bg-stone-100 rounded-lg font-bold"
                  >
                    -
                  </button>
                  <span className="w-10 text-center font-semibold text-stone-800 text-sm">
                    {quantity}
                  </span>
                  <button
                    onClick={() => setQuantity(Math.min(product.stock, quantity + 1))}
                    className="w-8 h-8 flex items-center justify-center text-stone-600 hover:bg-stone-100 rounded-lg font-bold"
                  >
                    +
                  </button>
                </div>

                {/* Add to Cart */}
                <button
                  onClick={handleAddToCart}
                  className="flex-1 w-full sm:w-auto py-3.5 px-6 rounded-xl bg-stone-900 text-white font-semibold text-sm hover:bg-stone-800 transition-colors flex items-center justify-center space-x-2 shadow-sm"
                >
                  <ShoppingCart className="w-4 h-4" />
                  <span>{addedNotice ? "Added to Cart!" : "Add to Cart"}</span>
                </button>

                {/* Buy Now */}
                <button
                  onClick={handleBuyNow}
                  className="flex-1 w-full sm:w-auto py-3.5 px-6 rounded-xl bg-[#C85A32] text-white font-semibold text-sm hover:bg-[#B34D28] transition-colors flex items-center justify-center space-x-2 shadow-sm"
                >
                  <Zap className="w-4 h-4 fill-white" />
                  <span>Buy Now</span>
                </button>
              </div>

              {/* B2B Wholesale Inquiry Button */}
              <div className="flex justify-between items-center text-xs pt-1">
                <span className="text-stone-500">Need 20+ pieces for corporate gifting or retail?</span>
                <button
                  onClick={() => setShowInquiryModal(true)}
                  className="text-[#2C3E6B] font-bold hover:underline flex items-center space-x-1"
                >
                  <MessageSquare className="w-3.5 h-3.5" />
                  <span>Request Wholesale Quote</span>
                </button>
              </div>
            </div>
          </div>
        </div>

        {/* ARTISAN STORY CARD */}
        {product.artisan && (
          <div className="mt-12 bg-white rounded-3xl p-6 sm:p-8 border border-stone-200/80 shadow-sm">
            <div className="flex flex-col sm:flex-row items-center sm:items-start gap-6">
              <img
                src={
                  product.artisan.profile_photo_url ||
                  "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=400"
                }
                alt={product.artisan.name}
                className="w-24 h-24 rounded-2xl object-cover border-2 border-stone-200 flex-shrink-0"
              />
              <div className="flex-1 text-center sm:text-left">
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 mb-2">
                  <div>
                    <span className="text-[10px] font-bold uppercase tracking-wider text-[#C85A32]">
                      Craftsperson Story
                    </span>
                    <h3 className="font-serif text-2xl font-bold text-stone-900">
                      {product.artisan.name}
                    </h3>
                  </div>
                  <Link
                    href={`/artisans/${product.artisan.id}`}
                    className="inline-flex items-center justify-center px-4 py-2 border border-stone-200 rounded-xl text-xs font-semibold text-stone-700 hover:bg-stone-50 transition-colors"
                  >
                    View All {product.artisan.product_count || "Craft"} Creations
                    <ChevronRight className="w-3.5 h-3.5 ml-1 text-stone-400" />
                  </Link>
                </div>
                <p className="text-stone-600 text-sm leading-relaxed mb-4">
                  {product.artisan.bio ||
                    `${product.artisan.name} is an indigenous master artisan from ${product.artisan.village}, ${product.artisan.state}, dedicated to keeping ancestral craft traditions alive.`}
                </p>
                <div className="flex flex-wrap items-center justify-center sm:justify-start gap-4 text-xs text-stone-500">
                  <div className="flex items-center space-x-1.5">
                    <Clock className="w-4 h-4 text-[#E09F3E]" />
                    <span>{product.artisan.years_experience || 15}+ Years of Craft Mastery</span>
                  </div>
                  <div className="flex items-center space-x-1.5">
                    <MapPin className="w-4 h-4 text-[#C85A32]" />
                    <span>
                      {product.artisan.village}, {product.artisan.district},{" "}
                      {product.artisan.state}
                    </span>
                  </div>
                  <div className="flex items-center space-x-1.5">
                    <Award className="w-4 h-4 text-emerald-600" />
                    <span>Verified KalaSathi Guild Artisan</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* REVIEWS SECTION */}
        <div className="mt-12 bg-white rounded-3xl p-6 sm:p-8 border border-stone-200/80 shadow-sm">
          <div className="flex items-center justify-between mb-6 border-b border-stone-100 pb-4">
            <div>
              <h3 className="font-serif text-xl font-bold text-stone-900">
                Verified Buyer Reviews
              </h3>
              <p className="text-xs text-stone-500">
                Real feedback from connoisseurs supporting rural craftsmen
              </p>
            </div>
            <div className="flex items-center space-x-4">
              <div className="flex items-center space-x-2">
                <div className="flex text-amber-500">
                  {[1, 2, 3, 4, 5].map((s) => (
                    <Star key={s} className="w-4 h-4 fill-current" />
                  ))}
                </div>
                <span className="font-bold text-stone-800 text-sm">5.0 / 5.0</span>
              </div>
              <button
                onClick={() => setShowReviewModal(true)}
                className="px-3.5 py-1.5 rounded-xl bg-[#C85A32] text-white text-xs font-semibold hover:bg-[#B34D28] transition shadow-sm"
              >
                Write a Review
              </button>
            </div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {reviewsList.map((rev, idx) => (
              <div key={idx} className="p-4 rounded-2xl bg-stone-50 border border-stone-100 space-y-2">
                <div className="flex items-center justify-between">
                  <span className="font-semibold text-stone-800 text-sm">{rev.name}</span>
                  <span className="text-[11px] text-stone-400">{rev.tag}</span>
                </div>
                <div className="flex text-amber-500">
                  {Array.from({ length: rev.rating }).map((_, s) => (
                    <Star key={s} className="w-3 h-3 fill-current" />
                  ))}
                </div>
                <p className="text-stone-600 text-xs leading-relaxed">
                  &quot;{rev.comment}&quot;
                </p>
              </div>
            ))}
          </div>
        </div>

      </div>

      {/* B2B INQUIRY MODAL */}
      {showInquiryModal && (
        <div className="fixed inset-0 z-50 bg-stone-900/60 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-white rounded-3xl max-w-lg w-full p-6 sm:p-8 shadow-2xl border border-stone-200 relative animate-in fade-in duration-200">
            <button
              onClick={() => setShowInquiryModal(false)}
              className="absolute top-5 right-5 text-stone-400 hover:text-stone-600 text-lg font-bold"
            >
              ✕
            </button>

            <div className="flex items-center space-x-2 text-xs font-bold uppercase tracking-wider text-[#C85A32] mb-1">
              <Package className="w-4 h-4" />
              <span>B2B Bulk & Corporate Inquiry</span>
            </div>
            <h3 className="font-serif text-2xl font-bold text-stone-900 mb-2">
              Order Wholesale Direct
            </h3>
            <p className="text-xs text-stone-600 mb-6">
              Your inquiry will be automatically translated into the artisan&apos;s native dialect ({product.artisan?.state}) and sent directly to their app.
            </p>

            {inquirySuccess ? (
              <div className="p-6 bg-emerald-50 rounded-2xl border border-emerald-200 text-center space-y-2">
                <CheckCircle2 className="w-10 h-10 text-emerald-600 mx-auto" />
                <h4 className="font-bold text-emerald-900 text-base">Inquiry Dispatched!</h4>
                <p className="text-xs text-emerald-700">
                  {product.artisan?.name} has received your inquiry in their native language app. Our guild manager will follow up with you.
                </p>
              </div>
            ) : (
              <form onSubmit={handleB2BSubmit} className="space-y-4">
                <div>
                  <label className="block text-xs font-semibold text-stone-700 mb-1">
                    Your Name / Organization *
                  </label>
                  <input
                    type="text"
                    required
                    value={inquiryName}
                    onChange={(e) => setInquiryName(e.target.value)}
                    placeholder="e.g. Ananya Roy / Craftroots Exports"
                    className="w-full px-3 py-2 text-sm border border-stone-300 rounded-xl focus:ring-2 focus:ring-[#C85A32] focus:outline-none"
                  />
                </div>

                <div>
                  <label className="block text-xs font-semibold text-stone-700 mb-1">
                    Email Address *
                  </label>
                  <input
                    type="email"
                    required
                    value={inquiryEmail}
                    onChange={(e) => setInquiryEmail(e.target.value)}
                    placeholder="name@company.com"
                    className="w-full px-3 py-2 text-sm border border-stone-300 rounded-xl focus:ring-2 focus:ring-[#C85A32] focus:outline-none"
                  />
                </div>

                <div>
                  <label className="block text-xs font-semibold text-stone-700 mb-1">
                    Estimated Quantity
                  </label>
                  <input
                    type="number"
                    min="10"
                    max="1000"
                    value={inquiryQty}
                    onChange={(e) => setInquiryQty(Number(e.target.value))}
                    className="w-full px-3 py-2 text-sm border border-stone-300 rounded-xl focus:ring-2 focus:ring-[#C85A32] focus:outline-none"
                  />
                </div>

                <div>
                  <label className="block text-xs font-semibold text-stone-700 mb-1">
                    Customization or Timeline Requirements
                  </label>
                  <textarea
                    rows={3}
                    value={inquiryMsg}
                    onChange={(e) => setInquiryMsg(e.target.value)}
                    placeholder="Special packaging, custom dimensions, or target delivery date..."
                    className="w-full px-3 py-2 text-sm border border-stone-300 rounded-xl focus:ring-2 focus:ring-[#C85A32] focus:outline-none"
                  />
                </div>

                <button
                  type="submit"
                  disabled={inquiryLoading}
                  className="w-full py-3 bg-[#C85A32] text-white rounded-xl font-semibold text-sm hover:bg-[#B34D28] transition-colors flex items-center justify-center space-x-2 shadow-sm disabled:opacity-50"
                >
                  <Send className="w-4 h-4" />
                  <span>{inquiryLoading ? "Submitting..." : "Send Translated Inquiry to Artisan"}</span>
                </button>
              </form>
            )}
          </div>
        </div>
      )}

      {/* WRITE A REVIEW MODAL */}
      {showReviewModal && (
        <div className="fixed inset-0 z-50 bg-stone-900/60 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-white rounded-3xl max-w-md w-full p-6 sm:p-8 shadow-2xl border border-stone-200 relative animate-in fade-in duration-200">
            <button
              onClick={() => setShowReviewModal(false)}
              className="absolute top-5 right-5 text-stone-400 hover:text-stone-600 text-lg font-bold"
            >
              ✕
            </button>

            <div className="flex items-center space-x-2 text-xs font-bold uppercase tracking-wider text-[#C85A32] mb-1">
              <Star className="w-4 h-4 fill-[#C85A32]" />
              <span>Verified Patron Feedback</span>
            </div>
            <h3 className="font-serif text-2xl font-bold text-stone-900 mb-2">
              Review this Handcrafted Creation
            </h3>
            <p className="text-xs text-stone-600 mb-5">
              Your words support {product.artisan?.name} and encourage sustainable rural livelihoods.
            </p>

            <form onSubmit={handleReviewSubmit} className="space-y-4">
              <div>
                <label className="block text-xs font-semibold text-stone-700 mb-1">
                  Overall Rating
                </label>
                <div className="flex space-x-2 text-amber-500">
                  {[1, 2, 3, 4, 5].map((star) => (
                    <button
                      type="button"
                      key={star}
                      onClick={() => setNewReviewRating(star)}
                      className="p-1 hover:scale-110 transition"
                    >
                      <Star
                        className={`w-6 h-6 ${
                          star <= newReviewRating ? "fill-current" : "text-stone-300"
                        }`}
                      />
                    </button>
                  ))}
                </div>
              </div>

              <div>
                <label className="block text-xs font-semibold text-stone-700 mb-1">
                  Your Name *
                </label>
                <input
                  type="text"
                  required
                  value={newReviewName}
                  onChange={(e) => setNewReviewName(e.target.value)}
                  placeholder="e.g. Ananya Deshpande"
                  className="w-full px-3 py-2 text-sm border border-stone-300 rounded-xl focus:ring-2 focus:ring-[#C85A32] focus:outline-none"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-stone-700 mb-1">
                  City / Town
                </label>
                <input
                  type="text"
                  value={newReviewCity}
                  onChange={(e) => setNewReviewCity(e.target.value)}
                  placeholder="e.g. Pune, MH"
                  className="w-full px-3 py-2 text-sm border border-stone-300 rounded-xl focus:ring-2 focus:ring-[#C85A32] focus:outline-none"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-stone-700 mb-1">
                  Review & Craftsmanship Feedback *
                </label>
                <textarea
                  rows={3}
                  required
                  value={newReviewComment}
                  onChange={(e) => setNewReviewComment(e.target.value)}
                  placeholder="Share details about texture, packaging, traditional detailing..."
                  className="w-full px-3 py-2 text-sm border border-stone-300 rounded-xl focus:ring-2 focus:ring-[#C85A32] focus:outline-none"
                />
              </div>

              <button
                type="submit"
                className="w-full py-3 bg-[#C85A32] text-white rounded-xl font-semibold text-sm hover:bg-[#B34D28] transition flex items-center justify-center space-x-2 shadow-sm"
              >
                <span>Submit Verified Review</span>
              </button>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}

