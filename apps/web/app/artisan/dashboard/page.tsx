"use client";

import React, { useState, useEffect, useRef } from "react";
import Link from "next/link";
import {
  Camera,
  Upload,
  Sparkles,
  CheckCircle2,
  AlertTriangle,
  RotateCcw,
  ArrowRight,
  ExternalLink,
  Layers,
  Image as ImageIcon,
  Check,
  RefreshCw,
  Loader2,
  Tag,
  DollarSign,
  Package,
} from "lucide-react";
import {
  createImageJob,
  fetchImageJob,
  fetchLatestImageJob,
  saveImageVariantSelection,
  createProduct,
  ImageJob,
  ImageVariant,
} from "@/lib/api";
import { useAuth } from "@/lib/auth-context";

const CATEGORIES = [
  "Pottery & Clay Crafts",
  "Handloom & Textiles",
  "Tribal & Folk Art",
  "Woodcraft & Carvings",
  "Jewelry & Metalcraft",
  "Home & Living",
];

const LOCAL_STORAGE_JOB_KEY = "kalasathi_active_job_id";

export default function ArtisanDashboardPage() {
  const { user, token } = useAuth();

  // Form State
  const [productName, setProductName] = useState("");
  const [productCategory, setProductCategory] = useState(CATEGORIES[0]);
  const [productDescription, setProductDescription] = useState("");
  const [productPrice, setProductPrice] = useState("850");
  const [productStock, setProductStock] = useState("5");
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);

  // Job State
  const [currentJob, setCurrentJob] = useState<ImageJob | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isPolling, setIsPolling] = useState(false);
  const [isSavingSelection, setIsSavingSelection] = useState(false);
  const [selectionSuccessMsg, setSelectionSuccessMsg] = useState<string | null>(null);
  const [selectedVariantIds, setSelectedVariantIds] = useState<string[]>([]);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  // Publishing State
  const [isPublishing, setIsPublishing] = useState(false);
  const [publishedProductId, setPublishedProductId] = useState<number | null>(null);

  const fileInputRef = useRef<HTMLInputElement>(null);
  const cameraInputRef = useRef<HTMLInputElement>(null);

  // 1. Restore active job from backend / localStorage on mount
  useEffect(() => {
    let isMounted = true;
    async function restoreJob() {
      try {
        const savedJobId = localStorage.getItem(LOCAL_STORAGE_JOB_KEY);
        let job: ImageJob | null = null;
        if (savedJobId) {
          try {
            job = await fetchImageJob(savedJobId, token || undefined);
          } catch (_) {
            job = null;
          }
        }
        if (!job && token) {
          job = await fetchLatestImageJob(token);
        }
        if (job && isMounted) {
          setCurrentJob(job);
          if (job.product_name) setProductName(job.product_name);
          if (job.product_category) setProductCategory(job.product_category);
          if (job.selected_variant_ids) {
            setSelectedVariantIds(job.selected_variant_ids);
          }
          if (job.original_photo?.image_url || job.original_photo_url) {
            setPreviewUrl(job.original_photo?.image_url || job.original_photo_url || null);
          }
        }
      } catch (_) {}
    }
    restoreJob();
    return () => {
      isMounted = false;
    };
  }, [token]);

  // 2. Poll job status if queued or running
  useEffect(() => {
    if (!currentJob) return;
    if (currentJob.status !== "queued" && currentJob.status !== "running") {
      setIsPolling(false);
      return;
    }

    setIsPolling(true);
    const interval = setInterval(async () => {
      try {
        const updated = await fetchImageJob(currentJob.job_id, token || undefined);
        setCurrentJob(updated);
        if (updated.selected_variant_ids && updated.selected_variant_ids.length > 0) {
          setSelectedVariantIds(updated.selected_variant_ids);
        }
        if (updated.status !== "queued" && updated.status !== "running") {
          setIsPolling(false);
          clearInterval(interval);
        }
      } catch (err) {
        // Continue polling until timeout or success
      }
    }, 3000);

    return () => clearInterval(interval);
  }, [currentJob?.job_id, currentJob?.status, token]);

  // Handle Photo selection
  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      setSelectedFile(file);
      setPreviewUrl(URL.createObjectURL(file));
      setErrorMessage(null);
      setSelectionSuccessMsg(null);
      setPublishedProductId(null);
    }
  };

  // Kickoff CrewAI workflow
  const handleGenerateImages = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedFile) {
      setErrorMessage("Please capture or select a product photo first.");
      return;
    }

    setIsSubmitting(true);
    setErrorMessage(null);
    setSelectionSuccessMsg(null);
    setPublishedProductId(null);

    try {
      const job = await createImageJob(
        selectedFile,
        productName || "Handmade Craft",
        productCategory,
        token || undefined
      );
      setCurrentJob(job);
      setSelectedVariantIds(job.selected_variant_ids || []);
      localStorage.setItem(LOCAL_STORAGE_JOB_KEY, job.job_id);
    } catch (err: any) {
      setErrorMessage(err.message || "Failed to start image processing. Please try again.");
    } finally {
      setIsSubmitting(false);
    }
  };

  // Toggle variant selection (Strict rule: exactly 3 can be selected)
  const handleToggleVariant = (variantId: string) => {
    setSelectionSuccessMsg(null);
    if (selectedVariantIds.includes(variantId)) {
      setSelectedVariantIds(selectedVariantIds.filter((id) => id !== variantId));
    } else {
      if (selectedVariantIds.length >= 3) {
        // Disallow selecting 4th; artisan must deselect one first
        return;
      }
      setSelectedVariantIds([...selectedVariantIds, variantId]);
    }
  };

  // Save variant selection to MongoDB
  const handleSaveSelection = async () => {
    if (!currentJob) return;
    if (selectedVariantIds.length !== 3) {
      setErrorMessage("Please select exactly 3 image variants.");
      return;
    }

    setIsSavingSelection(true);
    setErrorMessage(null);
    try {
      const updated = await saveImageVariantSelection(
        currentJob.job_id,
        selectedVariantIds,
        token || undefined
      );
      setCurrentJob(updated);
      setSelectedVariantIds(updated.selected_variant_ids);
      setSelectionSuccessMsg("Success! Exactly 3 variants saved to MongoDB.");
    } catch (err: any) {
      setErrorMessage(err.message || "Failed to save variant selection.");
    } finally {
      setIsSavingSelection(false);
    }
  };

  // Publish Product using the 3 selected variants
  const handlePublishProduct = async () => {
    if (!currentJob || selectedVariantIds.length !== 3) return;
    if (!token) {
      setErrorMessage("You must be logged in as an artisan to publish a product.");
      return;
    }

    setIsPublishing(true);
    setErrorMessage(null);

    try {
      const prod = await createProduct(
        {
          title_en: productName || currentJob.product_name || "Handcrafted Authentic Creation",
          description_en: productDescription || "Authentic handcrafted Indian craft.",
          price: parseFloat(productPrice) || 850,
          stock: parseInt(productStock) || 5,
          image_job_id: currentJob.job_id,
          selected_variant_ids: selectedVariantIds,
          status: "published",
        },
        token
      );
      setPublishedProductId(prod.id);
      setSelectionSuccessMsg("Product successfully published live to the web storefront!");
    } catch (err: any) {
      setErrorMessage(err.message || "Failed to publish product. Please check your inputs.");
    } finally {
      setIsPublishing(false);
    }
  };

  const isExact3Selected = selectedVariantIds.length === 3;
  const isRetake = currentJob?.status === "retake_required" || currentJob?.segmentation_status === "retake_required";
  const isFailed = currentJob?.status === "failed";
  const isCompleted = currentJob?.status === "completed";

  return (
    <div className="min-h-screen bg-[#FAF7F2] py-10 px-4 sm:px-6 lg:px-8">
      <div className="max-w-5xl mx-auto">
        {/* Header */}
        <div className="flex flex-col md:flex-row md:items-center md:justify-between border-b border-stone-200 pb-6 mb-8 gap-4">
          <div>
            <div className="flex items-center gap-2 mb-1">
              <span className="px-2.5 py-0.5 rounded-full text-xs font-bold uppercase tracking-wider bg-[#2C3E6B]/10 text-[#2C3E6B]">
                Artisan Studio
              </span>
              <span className="px-2.5 py-0.5 rounded-full text-xs font-bold uppercase tracking-wider bg-[#C85A32]/10 text-[#C85A32]">
                CrewAI Deployed Agent
              </span>
            </div>
            <h1 className="font-serif text-3xl font-extrabold text-stone-900">
              Product Studio & Catalog Generator
            </h1>
            <p className="text-stone-600 text-sm mt-1">
              Photograph your craft, generate 5-10 catalog-ready backgrounds, select exactly 3 variants, and publish to the website.
            </p>
          </div>
          <Link
            href="/products"
            className="inline-flex items-center gap-1.5 text-xs font-semibold text-[#2C3E6B] hover:underline"
          >
            View Live Storefront <ExternalLink className="w-3.5 h-3.5" />
          </Link>
        </div>

        {/* Global Error Banner */}
        {errorMessage && (
          <div className="mb-6 p-4 bg-red-50 border border-red-200 rounded-2xl flex items-start gap-3 text-red-800 text-sm">
            <AlertTriangle className="w-5 h-5 text-red-600 flex-shrink-0 mt-0.5" />
            <div className="flex-1 font-medium">{errorMessage}</div>
          </div>
        )}

        {/* Success Banner */}
        {selectionSuccessMsg && (
          <div className="mb-6 p-4 bg-emerald-50 border border-emerald-200 rounded-2xl flex items-center justify-between gap-3 text-emerald-800 text-sm">
            <div className="flex items-center gap-2.5 font-medium">
              <CheckCircle2 className="w-5 h-5 text-emerald-600 flex-shrink-0" />
              <span>{selectionSuccessMsg}</span>
            </div>
            {publishedProductId && (
              <Link
                href={`/products/${publishedProductId}`}
                className="px-3 py-1.5 bg-emerald-600 text-white font-semibold rounded-lg text-xs hover:bg-emerald-700 transition"
              >
                View Live Product &rarr;
              </Link>
            )}
          </div>
        )}

        <div className="grid grid-cols-1 lg:grid-cols-12 gap-8">
          {/* ─── Left Column: Product Information & Photo Input ─── */}
          <div className="lg:col-span-5 space-y-6">
            <div className="bg-white rounded-3xl p-6 border border-stone-200 shadow-sm">
              <h2 className="font-serif text-lg font-bold text-stone-900 mb-4 flex items-center gap-2">
                <span>1.</span> Product Information
              </h2>

              <form onSubmit={handleGenerateImages} className="space-y-4">
                <div>
                  <label className="block text-xs font-bold uppercase tracking-wider text-stone-600 mb-1">
                    Product Title *
                  </label>
                  <input
                    type="text"
                    required
                    value={productName}
                    onChange={(e) => setProductName(e.target.value)}
                    placeholder="e.g. Handcrafted Terracotta Water Pitcher"
                    className="w-full px-3.5 py-2.5 bg-stone-50 border border-stone-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-[#2C3E6B]"
                  />
                </div>

                <div>
                  <label className="block text-xs font-bold uppercase tracking-wider text-stone-600 mb-1">
                    Craft Category *
                  </label>
                  <select
                    value={productCategory}
                    onChange={(e) => setProductCategory(e.target.value)}
                    className="w-full px-3.5 py-2.5 bg-stone-50 border border-stone-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-[#2C3E6B]"
                  >
                    {CATEGORIES.map((c) => (
                      <option key={c} value={c}>
                        {c}
                      </option>
                    ))}
                  </select>
                </div>

                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="block text-xs font-bold uppercase tracking-wider text-stone-600 mb-1">
                      Price (₹)
                    </label>
                    <input
                      type="number"
                      value={productPrice}
                      onChange={(e) => setProductPrice(e.target.value)}
                      min="1"
                      className="w-full px-3.5 py-2.5 bg-stone-50 border border-stone-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-[#2C3E6B]"
                    />
                  </div>
                  <div>
                    <label className="block text-xs font-bold uppercase tracking-wider text-stone-600 mb-1">
                      Stock Count
                    </label>
                    <input
                      type="number"
                      value={productStock}
                      onChange={(e) => setProductStock(e.target.value)}
                      min="1"
                      className="w-full px-3.5 py-2.5 bg-stone-50 border border-stone-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-[#2C3E6B]"
                    />
                  </div>
                </div>

                <div>
                  <label className="block text-xs font-bold uppercase tracking-wider text-stone-600 mb-1">
                    Description
                  </label>
                  <textarea
                    rows={2}
                    value={productDescription}
                    onChange={(e) => setProductDescription(e.target.value)}
                    placeholder="Short description of craft technique and natural materials..."
                    className="w-full px-3.5 py-2 bg-stone-50 border border-stone-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-[#2C3E6B]"
                  />
                </div>

                {/* Photo Upload Area */}
                <div>
                  <label className="block text-xs font-bold uppercase tracking-wider text-stone-600 mb-1.5">
                    Original Product Photo *
                  </label>

                  <input
                    type="file"
                    ref={fileInputRef}
                    accept="image/*"
                    onChange={handleFileChange}
                    className="hidden"
                  />
                  <input
                    type="file"
                    ref={cameraInputRef}
                    accept="image/*"
                    capture="environment"
                    onChange={handleFileChange}
                    className="hidden"
                  />

                  {previewUrl ? (
                    <div className="relative rounded-2xl overflow-hidden border border-stone-200 group bg-stone-100 aspect-square max-h-64 mx-auto flex items-center justify-center">
                      <img
                        src={previewUrl}
                        alt="Product Preview"
                        className="w-full h-full object-cover"
                      />
                      <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition flex items-center justify-center gap-2">
                        <button
                          type="button"
                          onClick={() => fileInputRef.current?.click()}
                          className="px-3 py-1.5 bg-white text-stone-800 text-xs font-semibold rounded-lg hover:bg-stone-100 transition shadow"
                        >
                          Change Photo
                        </button>
                      </div>
                    </div>
                  ) : (
                    <div className="border-2 border-dashed border-stone-300 rounded-2xl p-6 text-center hover:border-stone-400 transition bg-stone-50/50">
                      <div className="w-12 h-12 bg-white rounded-full flex items-center justify-center mx-auto mb-3 shadow-sm text-stone-500">
                        <Camera className="w-6 h-6" />
                      </div>
                      <p className="text-xs text-stone-600 font-medium mb-3">
                        Take a photo using camera or choose from gallery
                      </p>
                      <div className="flex items-center justify-center gap-2">
                        <button
                          type="button"
                          onClick={() => cameraInputRef.current?.click()}
                          className="inline-flex items-center gap-1 px-3 py-2 bg-[#2C3E6B] text-white rounded-xl text-xs font-semibold hover:bg-[#202E50] transition"
                        >
                          <Camera className="w-3.5 h-3.5" />
                          Camera
                        </button>
                        <button
                          type="button"
                          onClick={() => fileInputRef.current?.click()}
                          className="inline-flex items-center gap-1 px-3 py-2 bg-stone-200 text-stone-800 rounded-xl text-xs font-semibold hover:bg-stone-300 transition"
                        >
                          <Upload className="w-3.5 h-3.5" />
                          Gallery
                        </button>
                      </div>
                    </div>
                  )}
                </div>

                <button
                  type="submit"
                  disabled={isSubmitting || isPolling || !selectedFile}
                  className="w-full py-3 px-4 bg-[#C85A32] text-white rounded-xl font-bold text-sm hover:bg-[#B34D28] transition disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2 shadow-sm shadow-[#C85A32]/20"
                >
                  {isSubmitting || isPolling ? (
                    <>
                      <Loader2 className="w-4 h-4 animate-spin" />
                      <span>Generating Studio Images...</span>
                    </>
                  ) : (
                    <>
                      <Sparkles className="w-4 h-4" />
                      <span>Generate Catalog Images</span>
                    </>
                  )}
                </button>
              </form>
            </div>
          </div>

          {/* ─── Right Column: Generated Variants & 3-Selection Studio ─── */}
          <div className="lg:col-span-7 space-y-6">
            <div className="bg-white rounded-3xl p-6 border border-stone-200 shadow-sm min-h-[500px] flex flex-col">
              <div className="flex flex-col sm:flex-row sm:items-center justify-between pb-4 border-b border-stone-100 mb-6 gap-2">
                <div>
                  <h2 className="font-serif text-lg font-bold text-stone-900 flex items-center gap-2">
                    <span>2.</span> AI Studio Background Variants
                  </h2>
                  <p className="text-xs text-stone-500 mt-0.5">
                    Select exactly <strong className="text-stone-800">THREE (3)</strong> variants for your catalog listing.
                  </p>
                </div>

                {/* Selection Counter Pill */}
                <div
                  className={`px-3.5 py-1.5 rounded-full text-xs font-bold inline-flex items-center gap-1.5 self-start sm:self-auto ${
                    isExact3Selected
                      ? "bg-emerald-100 text-emerald-800 border border-emerald-300"
                      : "bg-amber-100 text-amber-800 border border-amber-300"
                  }`}
                >
                  {isExact3Selected ? (
                    <CheckCircle2 className="w-3.5 h-3.5 text-emerald-600" />
                  ) : (
                    <Layers className="w-3.5 h-3.5 text-amber-600" />
                  )}
                  <span>
                    {selectedVariantIds.length} of 3 selected
                  </span>
                </div>
              </div>

              {/* State 1: Processing / Polling */}
              {(isSubmitting || isPolling) && (
                <div className="my-auto py-16 text-center">
                  <div className="w-16 h-16 bg-[#C85A32]/10 rounded-full flex items-center justify-center mx-auto mb-4 text-[#C85A32]">
                    <RefreshCw className="w-8 h-8 animate-spin" />
                  </div>
                  <h3 className="font-serif text-lg font-bold text-stone-800 mb-2">
                    Processing Image with CrewAI Agent...
                  </h3>
                  <p className="text-xs text-stone-500 max-w-sm mx-auto leading-relaxed">
                    Segmentation quality is being analyzed, shadows corrected, and studio color variations generated. This takes ~15–30 seconds.
                  </p>
                </div>
              )}

              {/* State 2: Retake Required */}
              {isRetake && !isPolling && (
                <div className="p-6 bg-amber-50 border border-amber-200 rounded-2xl mb-6 text-center">
                  <div className="w-12 h-12 bg-amber-100 text-amber-700 rounded-full flex items-center justify-center mx-auto mb-3">
                    <RotateCcw className="w-6 h-6" />
                  </div>
                  <h3 className="font-serif text-base font-bold text-amber-900 mb-1">
                    Retake Required
                  </h3>
                  <p className="text-xs text-amber-700 max-w-md mx-auto mb-4">
                    The AI agent detected that the craft photo has clipped edges or insufficient lighting. To preserve handcrafted detail, please retake a clear photo.
                  </p>
                  {currentJob?.quality_warnings && currentJob.quality_warnings.length > 0 && (
                    <ul className="text-xs text-amber-800 bg-amber-100/60 p-3 rounded-xl max-w-sm mx-auto text-left list-disc list-inside mb-4">
                      {currentJob.quality_warnings.map((w, idx) => (
                        <li key={idx}>{w}</li>
                      ))}
                    </ul>
                  )}
                  <button
                    type="button"
                    onClick={() => cameraInputRef.current?.click()}
                    className="inline-flex items-center gap-1.5 px-4 py-2 bg-amber-800 text-white rounded-xl text-xs font-bold hover:bg-amber-900 transition"
                  >
                    <Camera className="w-3.5 h-3.5" /> Retake Photo Now
                  </button>
                </div>
              )}

              {/* State 3: Failure */}
              {isFailed && !isPolling && (
                <div className="p-6 bg-red-50 border border-red-200 rounded-2xl mb-6 text-center">
                  <AlertTriangle className="w-10 h-10 text-red-500 mx-auto mb-2" />
                  <h3 className="font-serif text-base font-bold text-red-900 mb-1">
                    Processing Error
                  </h3>
                  <p className="text-xs text-red-700 max-w-md mx-auto mb-4">
                    {currentJob?.errors?.[0] || "CrewAI agent execution encountered an error."}
                  </p>
                  <button
                    type="button"
                    onClick={handleGenerateImages}
                    className="inline-flex items-center gap-1.5 px-4 py-2 bg-red-800 text-white rounded-xl text-xs font-bold hover:bg-red-900 transition"
                  >
                    <RefreshCw className="w-3.5 h-3.5" /> Try Again
                  </button>
                </div>
              )}

              {/* State 4: Initial Empty State */}
              {!currentJob && !isSubmitting && (
                <div className="my-auto py-16 text-center text-stone-400">
                  <div className="w-16 h-16 bg-stone-100 rounded-full flex items-center justify-center mx-auto mb-3">
                    <ImageIcon className="w-8 h-8 text-stone-300" />
                  </div>
                  <p className="text-sm font-medium text-stone-600 mb-1">No images generated yet</p>
                  <p className="text-xs text-stone-400 max-w-xs mx-auto">
                    Fill out the product information on the left and tap &quot;Generate Catalog Images&quot; to begin.
                  </p>
                </div>
              )}

              {/* State 5: Variants Display Grid */}
              {currentJob && currentJob.variants && currentJob.variants.length > 0 && !isPolling && (
                <div className="flex-1 flex flex-col justify-between">
                  <div className="grid grid-cols-2 sm:grid-cols-3 gap-3 mb-6">
                    {currentJob.variants.map((variant, idx) => {
                      const vid = variant.id || variant.variant_id || `var_${idx}`;
                      const isSelected = selectedVariantIds.includes(vid);
                      const bgName = variant.background?.name || variant.background?.type || `Variant ${idx + 1}`;
                      const bgHex = variant.background?.hex || "#FFFFFF";

                      return (
                        <div
                          key={vid}
                          onClick={() => handleToggleVariant(vid)}
                          className={`relative rounded-2xl overflow-hidden border-2 cursor-pointer transition p-1 bg-stone-50 flex flex-col ${
                            isSelected
                              ? "border-[#C85A32] shadow-md ring-2 ring-[#C85A32]/20"
                              : "border-stone-200 hover:border-stone-300 opacity-90 hover:opacity-100"
                          }`}
                        >
                          {/* Image Container */}
                          <div className="aspect-square rounded-xl overflow-hidden bg-stone-200 relative">
                            {variant.image_url ? (
                              <img
                                src={variant.image_url}
                                alt={bgName}
                                className="w-full h-full object-cover"
                              />
                            ) : (
                              <div className="w-full h-full flex items-center justify-center text-stone-400 text-xs">
                                No image URL
                              </div>
                            )}

                            {/* Checkbox badge */}
                            <div
                              className={`absolute top-2 right-2 w-6 h-6 rounded-full flex items-center justify-center shadow-sm transition ${
                                isSelected
                                  ? "bg-[#C85A32] text-white"
                                  : "bg-white/80 border border-stone-300 text-transparent hover:text-stone-300"
                              }`}
                            >
                              <Check className="w-3.5 h-3.5" />
                            </div>
                          </div>

                          {/* Background Label */}
                          <div className="pt-2 pb-1 px-1 flex items-center justify-between text-xs">
                            <span className="font-semibold text-stone-800 capitalize truncate">
                              {bgName}
                            </span>
                            <span
                              className="w-3.5 h-3.5 rounded-full border border-stone-300 flex-shrink-0"
                              style={{ backgroundColor: bgHex }}
                              title={bgHex}
                            />
                          </div>
                        </div>
                      );
                    })}
                  </div>

                  {/* Actions Section */}
                  <div className="pt-4 border-t border-stone-100 space-y-3">
                    <div className="flex flex-col sm:flex-row gap-3">
                      {/* Save Selection Button */}
                      <button
                        type="button"
                        onClick={handleSaveSelection}
                        disabled={!isExact3Selected || isSavingSelection}
                        className="flex-1 py-3 px-4 bg-[#2C3E6B] text-white rounded-xl text-xs font-bold hover:bg-[#1E2B4A] transition disabled:opacity-40 disabled:cursor-not-allowed flex items-center justify-center gap-1.5"
                      >
                        {isSavingSelection ? (
                          <>
                            <Loader2 className="w-3.5 h-3.5 animate-spin" />
                            <span>Saving Selection to MongoDB...</span>
                          </>
                        ) : (
                          <>
                            <CheckCircle2 className="w-3.5 h-3.5" />
                            <span>Save 3 Selected Variants</span>
                          </>
                        )}
                      </button>

                      {/* Publish Button */}
                      <button
                        type="button"
                        onClick={handlePublishProduct}
                        disabled={!isExact3Selected || isPublishing}
                        className="flex-1 py-3 px-4 bg-emerald-600 text-white rounded-xl text-xs font-bold hover:bg-emerald-700 transition disabled:opacity-40 disabled:cursor-not-allowed flex items-center justify-center gap-1.5 shadow-sm"
                      >
                        {isPublishing ? (
                          <>
                            <Loader2 className="w-3.5 h-3.5 animate-spin" />
                            <span>Publishing Product...</span>
                          </>
                        ) : (
                          <>
                            <ArrowRight className="w-3.5 h-3.5" />
                            <span>Publish to Storefront</span>
                          </>
                        )}
                      </button>
                    </div>

                    {!isExact3Selected && (
                      <p className="text-center text-xs text-stone-500">
                        {selectedVariantIds.length < 3
                          ? `Select ${3 - selectedVariantIds.length} more variant(s) to enable saving and publishing.`
                          : "Deselect one variant before selecting another (exactly 3 required)."}
                      </p>
                    )}
                  </div>
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
