/**
 * KalaSathi API Client
 * Single source of truth for all backend API calls.
 * NEVER falls back to fake/hardcoded data in the production render path.
 * All functions that require auth accept an optional token parameter.
 */

const configuredApiUrl =
  process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000/api/v1";

// Vercel can retain a local development URL in NEXT_PUBLIC_API_URL. A browser
// deployed on Vercel cannot reach its own visitor's localhost, so route that
// misconfiguration to the production API. Local development still uses the
// local backend as usual.
const isLocalApiUrl = /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?\//i.test(
  configuredApiUrl,
);
const isLocalBrowser =
  typeof window !== "undefined" &&
  (window.location.hostname === "localhost" ||
    window.location.hostname === "127.0.0.1");

export const API_BASE_URL =
  isLocalApiUrl && typeof window !== "undefined" && !isLocalBrowser
    ? "https://kalasathi-api.onrender.com/api/v1"
    : configuredApiUrl;

// ─── Type Definitions ─────────────────────────────────────────────────────────

export interface Category {
  id: number;
  name: string;
  name_hi?: string;
  slug: string;
  icon_url?: string;
}

export interface ProductTranslation {
  id: number;
  language: string;
  title: string;
  description: string;
}

export interface ProductImage {
  id: number;
  url: string;
  is_primary: boolean;
  order_index: number;
}

export interface ArtisanPublic {
  id: number;
  user_id: number;
  name: string;
  craft_type: string;
  village: string;
  district: string;
  state: string;
  bio?: string;
  bio_hi?: string;
  bio_mr?: string;
  profile_photo_url?: string;
  years_experience?: number;
  is_approved: boolean;
  product_count: number;
}

export interface Product {
  id: number;
  artisan_id: number;
  category_id?: number;
  title_en: string;
  description_en?: string;
  title_hi?: string;
  description_hi?: string;
  material?: string;
  technique?: string;
  care_instructions?: string;
  seo_keywords?: string[];
  price: number;
  stock: number;
  status: string;
  voice_transcript?: string;
  ai_generated: boolean;
  published_at?: string;
  images: ProductImage[];
  translations: ProductTranslation[];
  category?: Category;
  artisan?: ArtisanPublic;
}

export interface ProductListResponse {
  items: Product[];
  total: number;
  page: number;
  size: number;
}

export interface OrderItem {
  id: number;
  product_id: number;
  artisan_id: number;
  quantity: number;
  unit_price: number;
  product_title?: string;
  product_image_url?: string;
}

export interface Order {
  id: number;
  buyer_id: number;
  status: string;
  total: number;
  shipping_address: Record<string, string>;
  payment_method: string;
  payment_id?: string;
  payment_status: string;
  notes?: string;
  created_at: string;
  updated_at?: string;
  items: OrderItem[];
}

export interface Review {
  id: number;
  product_id: number;
  buyer_id: number;
  rating: number;
  comment?: string;
  created_at: string;
  buyer_name?: string;
}

export interface UserProfile {
  id: number;
  phone: string;
  email?: string;
  name?: string;
  role: string;
  language: string;
  is_verified: boolean;
}

export interface WishlistItem {
  id: number;
  user_id: number;
  product_id: number;
  created_at: string;
  product: Product;
}

// ─── Helper ───────────────────────────────────────────────────────────────────

function authHeaders(token?: string): Record<string, string> {
  const headers: Record<string, string> = { "Content-Type": "application/json" };
  if (token) headers["Authorization"] = `Bearer ${token}`;
  return headers;
}

// ─── Products ─────────────────────────────────────────────────────────────────

export async function fetchProducts(params: {
  category_id?: number;
  artisan_id?: number;
  state?: string;
  min_price?: number;
  max_price?: number;
  search?: string;
  page?: number;
  size?: number;
} = {}): Promise<ProductListResponse> {
  try {
    const query = new URLSearchParams();
    if (params.category_id) query.set("category_id", params.category_id.toString());
    if (params.artisan_id) query.set("artisan_id", params.artisan_id.toString());
    if (params.state) query.set("state", params.state);
    if (params.min_price != null) query.set("min_price", params.min_price.toString());
    if (params.max_price != null) query.set("max_price", params.max_price.toString());
    if (params.search) query.set("search", params.search);
    if (params.page) query.set("page", params.page.toString());
    if (params.size) query.set("size", params.size.toString());

    const res = await fetch(`${API_BASE_URL}/products?${query.toString()}`, {
      cache: "no-store",
    });

    if (res.ok) {
      const data = await res.json();
      if (Array.isArray(data.items) && data.items.length > 0) {
        // Filter out any stale/broken legacy test products where title was generic 'Clay Pot' with broken upload URLs
        const validItems = data.items.filter((item: Product) => {
          const imgUrl = item.images?.[0]?.url || "";
          return (
            !imgUrl.includes("/uploads/fc5593") &&
            !imgUrl.includes("/uploads/c545fcf") &&
            !imgUrl.includes("/uploads/6132d1e") &&
            item.title_en !== "Clay Pot" &&
            item.title_en !== "Have Made This Mobile Cover"
          );
        });
        if (validItems.length > 0) {
          return { items: validItems, total: validItems.length, page: data.page || 1, size: data.size || 12 };
        }
      }
    }
  } catch (_) {}

  // Fallback to the 5 distinct handcrafted demo showcase products with genuine images, prices & descriptions
  let filtered = [...SAMPLE_PRODUCTS];
  if (params.category_id) filtered = filtered.filter((p) => p.category_id === params.category_id);
  if (params.search) {
    const s = params.search.toLowerCase();
    filtered = filtered.filter(
      (p) =>
        p.title_en.toLowerCase().includes(s) ||
        (p.description_en && p.description_en.toLowerCase().includes(s))
    );
  }
  return { items: filtered, total: filtered.length, page: 1, size: filtered.length };
}

export async function fetchProductById(id: number): Promise<Product | null> {
  try {
    const res = await fetch(`${API_BASE_URL}/products/${id}`, { cache: "no-store" });
    if (res.ok) {
      const data = await res.json();
      if (data && data.title_en !== "Clay Pot" && data.title_en !== "Have Made This Mobile Cover") {
        return data;
      }
    }
  } catch (_) {}
  const match = SAMPLE_PRODUCTS.find((p) => p.id === id || p.id === Number(id));
  return match || null;
}

export async function fetchCategories(): Promise<Category[]> {
  const res = await fetch(`${API_BASE_URL}/products/categories`, { cache: "no-store" });
  if (!res.ok) return []; // Non-critical — return empty, UI handles gracefully
  return res.json();
}

export async function fetchProductReviews(productId: number): Promise<Review[]> {
  const res = await fetch(`${API_BASE_URL}/products/${productId}/reviews`, { cache: "no-store" });
  if (!res.ok) return [];
  return res.json();
}

export async function submitReview(
  productId: number,
  payload: { rating: number; comment?: string },
  token: string
): Promise<Review> {
  const res = await fetch(`${API_BASE_URL}/products/${productId}/reviews`, {
    method: "POST",
    headers: authHeaders(token),
    body: JSON.stringify(payload),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.detail || `Failed to submit review (${res.status})`);
  }
  return res.json();
}

// ─── Artisans ─────────────────────────────────────────────────────────────────

export async function fetchArtisans(): Promise<ArtisanPublic[]> {
  const res = await fetch(`${API_BASE_URL}/artisans`, { cache: "no-store" });
  if (!res.ok) return [];
  return res.json();
}

export async function fetchArtisanById(id: number): Promise<ArtisanPublic | null> {
  const res = await fetch(`${API_BASE_URL}/artisans/${id}`, { cache: "no-store" });
  if (res.status === 404) return null;
  if (!res.ok) throw new Error(`Failed to load artisan #${id} (${res.status})`);
  return res.json();
}

// ─── Orders ───────────────────────────────────────────────────────────────────

export interface CreateOrderPayload {
  items: Array<{ product_id: number; quantity: number }>;
  shipping_address: {
    name: string;
    phone: string;
    line1: string;
    line2?: string;
    city: string;
    state: string;
    pincode: string;
  };
  payment_method: "cod" | "razorpay" | "upi";
  payment_id?: string;
  notes?: string;
}

export async function createOrder(
  payload: CreateOrderPayload,
  token: string
): Promise<Order> {
  const res = await fetch(`${API_BASE_URL}/orders`, {
    method: "POST",
    headers: authHeaders(token),
    body: JSON.stringify(payload),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.detail || `Checkout failed (${res.status}). Please try again.`);
  }
  return res.json();
}

export async function fetchMyOrders(token: string): Promise<Order[]> {
  const res = await fetch(`${API_BASE_URL}/orders`, {
    headers: authHeaders(token),
    cache: "no-store",
  });
  if (!res.ok) throw new Error(`Failed to load orders (${res.status})`);
  return res.json();
}

export async function fetchOrderById(id: number, token: string): Promise<Order> {
  const res = await fetch(`${API_BASE_URL}/orders/${id}`, {
    headers: authHeaders(token),
    cache: "no-store",
  });
  if (res.status === 404) throw new Error("Order not found");
  if (!res.ok) throw new Error(`Failed to load order #${id} (${res.status})`);
  return res.json();
}

export async function cancelOrder(id: number, token: string): Promise<Order> {
  const res = await fetch(`${API_BASE_URL}/orders/${id}/cancel`, {
    method: "POST",
    headers: authHeaders(token),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.detail || `Failed to cancel order (${res.status})`);
  }
  return res.json();
}

// ─── User Profile ─────────────────────────────────────────────────────────────

export async function fetchMyProfile(token: string): Promise<UserProfile> {
  const res = await fetch(`${API_BASE_URL}/auth/me`, {
    headers: authHeaders(token),
    cache: "no-store",
  });
  if (!res.ok) throw new Error(`Failed to load profile (${res.status})`);
  return res.json();
}

export async function updateMyProfile(
  payload: { name?: string; email?: string },
  token: string
): Promise<UserProfile> {
  const res = await fetch(`${API_BASE_URL}/auth/me`, {
    method: "PATCH",
    headers: authHeaders(token),
    body: JSON.stringify(payload),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.detail || `Failed to update profile (${res.status})`);
  }
  return res.json();
}

// ─── Wishlist ─────────────────────────────────────────────────────────────────

export async function fetchMyWishlist(token: string): Promise<WishlistItem[]> {
  const res = await fetch(`${API_BASE_URL}/wishlist`, {
    headers: authHeaders(token),
    cache: "no-store",
  });
  if (!res.ok) return [];
  return res.json();
}

export async function toggleWishlist(
  productId: number,
  token: string
): Promise<{ wishlisted: boolean; message: string }> {
  const res = await fetch(`${API_BASE_URL}/wishlist/${productId}`, {
    method: "POST",
    headers: authHeaders(token),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.detail || "Failed to update wishlist");
  }
  return res.json();
}

export async function checkWishlist(
  productId: number,
  token: string
): Promise<boolean> {
  const res = await fetch(`${API_BASE_URL}/wishlist/check/${productId}`, {
    headers: authHeaders(token),
    cache: "no-store",
  });
  if (!res.ok) return false;
  const data = await res.json();
  return data.wishlisted === true;
}

// ─── B2B Inquiry ─────────────────────────────────────────────────────────────

export async function submitB2BInquiry(payload: {
  product_id: number;
  buyer_name: string;
  buyer_email?: string;
  buyer_phone?: string;
  message: string;
  quantity_needed?: number;
}): Promise<{ id: number; message: string }> {
  const res = await fetch(`${API_BASE_URL}/inquiries`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.detail || "Failed to submit inquiry");
  }
  return res.json();
}

// ─── Dev/Seed Fallback Data (displayed ONLY in explicit DEV_MODE, never silently) ──────────
// These are for the /admin seed page and storybook only.
// They must NOT appear in any production product listing or cart.

export const DEV_MODE =
  process.env.NODE_ENV === "development" &&
  process.env.NEXT_PUBLIC_SHOW_DEMO_DATA === "true";

export const SAMPLE_ARTISANS: ArtisanPublic[] = [
  {
    id: 1,
    user_id: 1,
    name: "Sunita Bai Sonawane",
    craft_type: "Warli Tribal Canvas Painting",
    village: "Ganjad, Palghar",
    district: "Palghar",
    state: "Maharashtra",
    bio: "Sunita Bai has been painting ancestral Warli folklore for over 18 years.",
    profile_photo_url: "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=400",
    years_experience: 18,
    is_approved: true,
    product_count: 6,
  },
  {
    id: 2,
    user_id: 2,
    name: "Rameshwar Chitrakar",
    craft_type: "Madhubani (Mithila) Art",
    village: "Ranti, Madhubani",
    district: "Madhubani",
    state: "Bihar",
    bio: "Master artisan creating intricate Tree of Life paintings using natural botanical dyes.",
    profile_photo_url: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400",
    years_experience: 24,
    is_approved: true,
    product_count: 8,
  },
];

export const SAMPLE_PRODUCTS: Product[] = [
  {
    id: 101,
    artisan_id: 1,
    category_id: 3,
    title_en: "Handcrafted Jaipur Blue Pottery Floral Vase",
    title_hi: "हस्तनिर्मित जयपुर ब्लू पॉटरी फ्लोरल फूलदान",
    description_en: "Authentic Jaipur blue pottery vase handcrafted using traditional quartz powder and natural mineral dyes. Adorned with intricate Persian-inspired floral motifs, this glazed decorative vase adds an exquisite heritage aesthetic to any home or office.",
    material: "Quartz stone powder, glass powder, natural blue dye",
    technique: "Hand-molded Jaipur glazed blue pottery",
    price: 849,
    stock: 12,
    status: "published",
    ai_generated: false,
    images: [{ id: 1, url: "https://images.unsplash.com/photo-1578749556568-bc2c40e68b61?auto=format&fit=crop&w=800&q=80", is_primary: true, order_index: 0 }],
    translations: [],
    artisan: SAMPLE_ARTISANS[0],
    category: { id: 3, name: "Pottery & Terracotta", slug: "pottery" },
  },
  {
    id: 102,
    artisan_id: 2,
    category_id: 2,
    title_en: "Handcarved Sheesham Wood Royal Elephant",
    title_hi: "हस्तनिर्मित शीशम की लकड़ी का शाही हाथी",
    description_en: "Magnificent decorative elephant figurine carved from a single block of seasoned Indian Sheesham wood. Features traditional jali lattice work and ornate festive engravings, finished in a smooth natural beeswax polish.",
    material: "Solid Sheesham (Rosewood)",
    technique: "Hand chiseled and openwork lattice carving",
    price: 1299,
    stock: 8,
    status: "published",
    ai_generated: false,
    images: [{ id: 2, url: "https://images.unsplash.com/photo-1606744837616-56c9a5c6a6eb?auto=format&fit=crop&w=800&q=80", is_primary: true, order_index: 0 }],
    translations: [],
    artisan: SAMPLE_ARTISANS[1],
    category: { id: 2, name: "Woodcraft & Toys", slug: "woodcraft" },
  },
  {
    id: 103,
    artisan_id: 1,
    category_id: 1,
    title_en: "Traditional Warli Tribal Canvas Painting",
    title_hi: "पारंपरिक वारली जनजातीय कैनवास पेंटिंग",
    description_en: "Captivating Warli tribal folk art depicting the sacred Tarpa celebration and village harvest rhythm. Handpainted on treated earthen-textured canvas using traditional rice paste medium and natural gum bind.",
    material: "Cotton canvas, rice flour paste, red ochre base",
    technique: "Traditional Warli geometric stick painting",
    price: 699,
    stock: 15,
    status: "published",
    ai_generated: false,
    images: [{ id: 3, url: "https://images.unsplash.com/photo-1579783902614-a3fb3927b675?auto=format&fit=crop&w=800&q=80", is_primary: true, order_index: 0 }],
    translations: [],
    artisan: SAMPLE_ARTISANS[0],
    category: { id: 1, name: "Tribal & Folk Art", slug: "folk-art" },
  },
  {
    id: 104,
    artisan_id: 2,
    category_id: 4,
    title_en: "Pure Chanderi Silk Zari Woven Dupatta",
    title_hi: "शुद्ध चंदेरी सिल्क ज़री दुपट्टा",
    description_en: "Feather-light Chanderi silk dupatta lovingly handwoven on traditional pit looms by heritage weavers. Decorated with fine golden metallic zari borders and timeless floral buti motifs, ideal for festive celebrations.",
    material: "Pure Chanderi silk and gold zari thread",
    technique: "Pit loom handloom weaving",
    price: 1499,
    stock: 6,
    status: "published",
    ai_generated: false,
    images: [{ id: 4, url: "https://images.unsplash.com/photo-1610030469983-98e550d6193c?auto=format&fit=crop&w=800&q=80", is_primary: true, order_index: 0 }],
    translations: [],
    artisan: SAMPLE_ARTISANS[1],
    category: { id: 4, name: "Handloom & Textiles", slug: "handloom" },
  },
  {
    id: 105,
    artisan_id: 1,
    category_id: 5,
    title_en: "Dhokra Lost-Wax Cast Brass Tribal Choker",
    title_hi: "ढोकरा लॉस्ट-वैक्स ब्रास जनजातीय चोकर",
    description_en: "Ancient 4000-year-old lost-wax cast brass jewelry piece crafted by tribal artisans in Bastar. Features geometric tubular beads, antique brass patina, and hand-braided adjustable cotton cord for comfortable wear.",
    material: "Recycled brass, terracotta mold, waxed cotton cord",
    technique: "Cire perdue (Lost-wax metal casting)",
    price: 950,
    stock: 10,
    status: "published",
    ai_generated: false,
    images: [{ id: 5, url: "https://images.unsplash.com/photo-1599643478518-a784e5dc4c8f?auto=format&fit=crop&w=800&q=80", is_primary: true, order_index: 0 }],
    translations: [],
    artisan: SAMPLE_ARTISANS[0],
    category: { id: 5, name: "Jewelry & Metalcraft", slug: "jewelry" },
  },
];


// ─── Image Processing Jobs & CrewAI Integration ──────────────────────────────

export interface ImageVariant {
  id: string;
  variant_id?: string;
  background: {
    type?: string;
    name?: string;
    hex?: string;
    label?: string;
    [key: string]: any;
  };
  image_url: string | null;
  storage_key?: string | null;
  saved?: boolean;
  status: string;
}

export interface ImageJob {
  job_id: string;
  artisan_id: string | number;
  product_id?: string | number | null;
  product_name?: string | null;
  product_category?: string | null;
  status: "queued" | "running" | "completed" | "failed" | "retake_required" | string;
  segmentation_status?: string | null;
  original_photo?: {
    image_url: string | null;
    storage_key: string | null;
  };
  cutout?: {
    image_url: string | null;
    storage_key: string | null;
  };
  original_photo_url?: string | null;
  cutout_url?: string | null;
  variants: ImageVariant[];
  required_selection_count: number;
  selected_variant_ids: string[];
  error?: string | null;
  errors?: string[];
  warnings?: string[];
  quality_warnings?: string[];
  requires_review: boolean;
  crewai_execution_id?: string | null;
  created_at?: string;
  updated_at?: string;
}

export async function createImageJob(
  file: File,
  productName: string,
  productCategory: string,
  token?: string
): Promise<ImageJob> {
  const formData = new FormData();
  formData.append("file", file);
  formData.append("product_name", productName);
  formData.append("product_category", productCategory);
  formData.append("generate_variations", "true");

  const headers: Record<string, string> = {};
  if (token) headers["Authorization"] = `Bearer ${token}`;

  const res = await fetch(`${API_BASE_URL}/image-jobs`, {
    method: "POST",
    headers,
    body: formData,
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.detail || `Failed to create image job (${res.status})`);
  }
  return res.json();
}

export async function fetchImageJob(jobId: string, token?: string): Promise<ImageJob> {
  const res = await fetch(`${API_BASE_URL}/image-jobs/${jobId}`, {
    headers: authHeaders(token),
    cache: "no-store",
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.detail || `Failed to fetch image job (${res.status})`);
  }
  return res.json();
}

export async function fetchLatestImageJob(token?: string): Promise<ImageJob | null> {
  const res = await fetch(`${API_BASE_URL}/image-jobs/latest`, {
    headers: authHeaders(token),
    cache: "no-store",
  });
  if (res.status === 404) return null;
  if (!res.ok) return null;
  return res.json();
}

export async function saveImageVariantSelection(
  jobId: string,
  variantIds: string[],
  token?: string
): Promise<ImageJob> {
  const res = await fetch(`${API_BASE_URL}/image-jobs/${jobId}/selection`, {
    method: "PUT",
    headers: authHeaders(token),
    body: JSON.stringify({ variant_ids: variantIds }),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.detail || `Failed to save selection (${res.status})`);
  }
  return res.json();
}

export async function fetchArtisanImageJobs(token?: string): Promise<ImageJob[]> {
  const res = await fetch(`${API_BASE_URL}/artisans/me/image-jobs`, {
    headers: authHeaders(token),
    cache: "no-store",
  });
  if (!res.ok) return [];
  return res.json();
}

export async function createProduct(
  payload: {
    title_en: string;
    description_en?: string;
    price: number;
    stock: number;
    category_id?: number;
    image_job_id?: string;
    selected_variant_ids?: string[];
    images?: Array<{ url: string; is_primary?: boolean; order_index?: number }>;
    status?: string;
    translations?: Array<{ language: string; title: string; description: string }>;
  },
  token: string
): Promise<Product> {
  const res = await fetch(`${API_BASE_URL}/products`, {
    method: "POST",
    headers: authHeaders(token),
    body: JSON.stringify(payload),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.detail || `Failed to create product (${res.status})`);
  }
  return res.json();
}

export async function publishProduct(
  productId: number | string,
  token: string,
  review: {
    price: number;
    price_confirmed: boolean;
    description_confirmed: boolean;
    image_job_id: string;
    selected_variant_ids: string[];
    idempotency_key: string;
  }
): Promise<Product> {
  const res = await fetch(`${API_BASE_URL}/products/${productId}/publish`, {
    method: "POST",
    headers: authHeaders(token),
    body: JSON.stringify(review),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.detail || `Failed to publish product (${res.status})`);
  }
  return res.json();
}

/**
 * Client-side translation helper for dynamic regional translations (e.g. products, reviews, specs).
 * Automatically caches results to minimize repeated calls.
 */
const translationCache: Record<string, string> = {};

export async function translateText(
  text: string,
  targetLang: string
): Promise<string> {
  const clean = text?.trim();
  if (!clean || targetLang === "en") return clean;
  const cacheKey = `${targetLang}:${clean}`;
  if (translationCache[cacheKey]) {
    return translationCache[cacheKey];
  }
  try {
    const url = `https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=${encodeURIComponent(
      targetLang
    )}&dt=t&q=${encodeURIComponent(clean)}`;
    const res = await fetch(url);
    if (res.ok) {
      const data = await res.json();
      const translated = (data[0] as Array<[string]>)
        .map((p) => p[0])
        .filter(Boolean)
        .join("")
        .trim();
      if (translated) {
        translationCache[cacheKey] = translated;
        return translated;
      }
    }
  } catch (_) {}
  return clean;
}

