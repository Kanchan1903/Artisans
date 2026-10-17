export const API_BASE_URL =
  process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000/api/v1";

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

// ─── API Methods ─────────────────────────────────────────────────────────────

export async function fetchProducts(params: {
  category_id?: number;
  state?: string;
  min_price?: number;
  max_price?: number;
  search?: string;
  page?: number;
  size?: number;
} = {}): Promise<{ items: Product[]; total: number }> {
  try {
    const query = new URLSearchParams();
    if (params.category_id) query.set("category_id", params.category_id.toString());
    if (params.state) query.set("state", params.state);
    if (params.min_price) query.set("min_price", params.min_price.toString());
    if (params.max_price) query.set("max_price", params.max_price.toString());
    if (params.search) query.set("search", params.search);
    if (params.page) query.set("page", params.page.toString());
    if (params.size) query.set("size", params.size.toString());

    const res = await fetch(`${API_BASE_URL}/products?${query.toString()}`, {
      cache: "no-store",
    });
    if (res.ok) {
      return await res.json();
    }
  } catch (err) {
    // API not running or network error, return fallback
  }

  return {
    items: SAMPLE_PRODUCTS,
    total: SAMPLE_PRODUCTS.length,
  };
}

export async function fetchProductById(id: number): Promise<Product | null> {
  try {
    const res = await fetch(`${API_BASE_URL}/products/${id}`, { cache: "no-store" });
    if (res.ok) {
      return await res.json();
    }
  } catch (err) {}
  return SAMPLE_PRODUCTS.find((p) => p.id === id) || SAMPLE_PRODUCTS[0];
}

export async function fetchCategories(): Promise<Category[]> {
  try {
    const res = await fetch(`${API_BASE_URL}/products/categories`, { cache: "no-store" });
    if (res.ok) {
      return await res.json();
    }
  } catch (err) {}
  return [
    { id: 1, name: "Pottery & Terracotta", name_hi: "मिट्टी के बर्तन", slug: "pottery" },
    { id: 2, name: "Handloom & Textiles", name_hi: "हथकरघा और वस्त्र", slug: "handloom" },
    { id: 3, name: "Tribal & Folk Art", name_hi: "जनजातीय और लोक कला", slug: "folk-art" },
    { id: 4, name: "Woodcraft & Toys", name_hi: "काष्ठकला और खिलौने", slug: "woodcraft" },
    { id: 5, name: "Jewelry & Beads", name_hi: "पारंपरिक आभूषण", slug: "jewelry" },
  ];
}

export async function fetchArtisans(): Promise<ArtisanPublic[]> {
  try {
    const res = await fetch(`${API_BASE_URL}/artisans`, { cache: "no-store" });
    if (res.ok) {
      return await res.json();
    }
  } catch (err) {}
  return SAMPLE_ARTISANS;
}

export async function fetchArtisanById(id: number): Promise<ArtisanPublic | null> {
  try {
    const res = await fetch(`${API_BASE_URL}/artisans/${id}`, { cache: "no-store" });
    if (res.ok) {
      return await res.json();
    }
  } catch (err) {}
  return SAMPLE_ARTISANS.find((a) => a.id === id) || SAMPLE_ARTISANS[0];
}

export async function fetchOrderById(id: number): Promise<any> {
  try {
    const res = await fetch(`${API_BASE_URL}/orders/${id}`, { cache: "no-store" });
    if (res.ok) {
      return await res.json();
    }
  } catch (err) {}
  return {
    id,
    status: "accepted",
    total: 1800,
    shipping_address: "Flat 402, Lotus Towers, Pune, Maharashtra 411038",
    payment_method: "Razorpay (UPI / Card)",
    payment_status: "paid",
    tracking_number: `KS-TRK-${id}`,
    estimated_delivery: "Within 4-6 business days",
    created_at: new Date(Date.now() - 3600000 * 4).toISOString(),
    items: [
      {
        id: 1,
        product_id: 1,
        title: "Warli Village Harvest Celebration Canvas",
        quantity: 1,
        unit_price: 1800,
        image_url: "https://images.unsplash.com/photo-1582562124811-c09040d0a901?w=800",
      },
    ],
  };
}

export async function createOrder(payload: any): Promise<any> {
  try {
    const res = await fetch(`${API_BASE_URL}/orders`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
    if (res.ok) {
      return await res.json();
    }
  } catch (err) {}
  return {
    id: Math.floor(Math.random() * 9000) + 1000,
    status: "pending",
    total: payload.items?.reduce((acc: number, item: any) => acc + (item.unit_price || 500) * (item.quantity || 1), 0) || 1200,
    shipping_address: payload.shipping_address,
    created_at: new Date().toISOString(),
  };
}

export async function submitB2BInquiry(payload: {
  product_id: number;
  buyer_name: string;
  buyer_email: string;
  message: string;
  quantity_needed?: number;
}): Promise<any> {
  try {
    const res = await fetch(`${API_BASE_URL}/inquiries`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
    if (res.ok) {
      return await res.json();
    }
  } catch (err) {}
  return { id: 101, message: "Inquiry submitted successfully" };
}

// ─── Sample Fallback Data ────────────────────────────────────────────────────

export const SAMPLE_ARTISANS: ArtisanPublic[] = [
  {
    id: 1,
    user_id: 1,
    name: "Sunita Bai Sonawane",
    craft_type: "Warli Tribal Canvas Painting",
    village: "Ganjad, Palghar",
    district: "Palghar",
    state: "Maharashtra",
    bio: "Sunita Bai has been painting ancestral Warli folklore for over 18 years, preserving indigenous traditions through natural rice paste pigments.",
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
    bio: "Master artisan creating intricate Tree of Life and Kohbar Mithila paintings using twig nibs and natural botanical dyes.",
    profile_photo_url: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400",
    years_experience: 24,
    is_approved: true,
    product_count: 8,
  },
  {
    id: 3,
    user_id: 3,
    name: "Basavaraju Gudigar",
    craft_type: "Channapatna Lacquerware Woodcraft",
    village: "Channapatna",
    district: "Ramanagara",
    state: "Karnataka",
    bio: "State-recognized wooden craftsperson turning ivory wood on traditional lathe machines using non-toxic vegetable dyes.",
    profile_photo_url: "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400",
    years_experience: 20,
    is_approved: true,
    product_count: 6,
  },
];

export const SAMPLE_PRODUCTS: Product[] = [
  {
    id: 1,
    artisan_id: 1,
    category_id: 3,
    title_en: "Warli Village Harvest Celebration Canvas",
    description_en: "Authentic handmade Warli painting on treated earthen canvas depicting the sacred Tarpa dance and bumper harvest celebration. Created using organic rice flour paste and natural resin gum.",
    title_hi: "वारली ग्राम फसल उत्सव कैनवास चित्रकला",
    description_hi: "चावल के आटे और प्राकृतिक गोंद से निर्मित पारंपरिक वारली चित्रकला, जिसमें तारपा नृत्य और फसल उत्सव दर्शाया गया है।",
    material: "Handspun Cotton, Rice Flour Paste, Organic Gum",
    technique: "Freehand Bamboo Twig Painting",
    care_instructions: "Keep away from moisture. Dust gently with dry micro-fiber cloth.",
    price: 1800,
    stock: 4,
    status: "published",
    ai_generated: true,
    published_at: "2026-10-15T10:00:00Z",
    images: [
      { id: 1, url: "https://images.unsplash.com/photo-1582562124811-c09040d0a901?w=800", is_primary: true, order_index: 0 },
    ],
    translations: [
      { id: 1, language: "en", title: "Warli Village Harvest Celebration Canvas", description: "Authentic handmade Warli painting on treated earthen canvas depicting the sacred Tarpa dance." },
      { id: 2, language: "hi", title: "वारली ग्राम फसल उत्सव कैनवास चित्रकला", description: "चावल के आटे और प्राकृतिक गोंद से निर्मित पारंपरिक वारली चित्रकला।" },
      { id: 3, language: "mr", title: "वारली गाव पीक उत्सव कॅनव्हास चित्रकला", description: "तांदळाचे पीठ आणि नैसर्गिक डिंकाचा वापर करून बांबूच्या काडीने हाताने रंगवलेली अस्सल वारली चित्रकला." },
      { id: 4, language: "bn", title: "ওয়ারলি গ্রাম ফসল উৎসব ক্যানভাস চিত্রকলা", description: "চালগুঁড়োর প্রাকৃতিক রঙ্গে আঁকা মহারাষ্ট্রের ঐতিহ্যবাহী ওয়ারলি চিত্রকর্ম।" },
      { id: 5, language: "ta", title: "வார்லி கிராம அறுவடை ஓவியம்", description: "அரிசி மாவு மற்றும் இயற்கை பிசின் கொண்டு வரையப்பட்ட பாரம்பரிய வார்லி ஓவியம்." },
      { id: 6, language: "te", title: "వార్లీ గ్రామీణ పంట సంబరాల కాన్వాస్ చిత్రం", description: "బియ్యపు పిండి మరియు సహజ రంగులతో గీసిన సాంప్రదాయ వార్లీ పెయింటింగ్." },
      { id: 7, language: "kn", title: "ವಾರ್ಲಿ ಹಳ್ಳಿ ಸುಗ್ಗಿ ಹಬ್ಬದ ಚಿತ್ರಕಲೆ", description: "ಅಕ್ಕಿ ಹಿಟ್ಟು ಮತ್ತು ನೈಸರ್ಗಿಕ ಜಿಗುಟಿನಿಂದ ರಚಿಸಲಾದ ಸಾಂಪ್ರದಾಯಿಕ ವಾರ್ಲಿ ಕಲೆ." },
      { id: 8, language: "ml", title: "വാർലി ഗ്രാമീണ വിളവെടുപ്പ് കാൻവാസ് ചിത്രം", description: "അരിപ്പൊടിയും പ്രകൃതിദത്ത പശയും ഉപയോഗിച്ച് വരച്ച പരമ്പരാഗത വാർലി കല." },
      { id: 9, language: "gu", title: "વારલી ગ્રામીણ લણણી ઉત્સવ કેનવાસ ચિત્રકળા", description: "ચોખાના લોટ અને કુદરતી ગુંદરથી વાંસની સળી વડે બનાવેલું વારલી ચિત્ર." },
      { id: 10, language: "pa", title: "ਵਾਰਲੀ ਪੇਂਡੂ ਵਾਢੀ ਉਤਸਵ ਕੈਨਵਸ ਪੇਂਟਿੰਗ", description: "ਚੌਲਾਂ ਦੇ ਆਟੇ ਅਤੇ ਕੁਦਰતી ਗੂੰਦ ਨਾਲ ਤਿਆਰ ਕੀਤੀ ਗਈ ਰਵਾਇਤੀ ਪੇਂਟਿੰਗ।" },
      { id: 11, language: "or", title: "ୱାର୍ଲି ଗ୍ରାମୀଣ ଅମଳ ଉତ୍ସବ କାନଭାସ ଚିତ୍ରକଳା", description: "ଚାଉଳ ଚୂନା ଏବଂ ପ୍ରାକୃତିକ ଅଠାରେ ତିଆରି ପାରମ୍ପରିକ ୱାର୍ଲି ଚିତ୍ରକଳା।" },
      { id: 12, language: "as", title: "ৱাৰ্লি গাঁৱলীয়া শস্য চপোৱা উৎসৱৰ কেনভাচ ছবি", description: "চাউলৰ গুড়ি আৰু প্ৰাকৃতিক আঠাৰে তৈয়াৰী পৰম্পৰাগত ৱাৰ্লি ছবি।" },
    ],
    artisan: SAMPLE_ARTISANS[0],
  },
  {
    id: 2,
    artisan_id: 2,
    category_id: 3,
    title_en: "Madhubani Tree of Life Mithila Painting",
    description_en: "Intricate symbolic Tree of Life canvas embodying spiritual harmony and prosperity, rendered with fine bamboo nibs in authentic Kachni style.",
    title_hi: "मधुबनी जीवन वृक्ष मिथिला चित्रकला",
    description_hi: "कचनी शैली में निर्मित मधुबनी जीवन वृक्ष, जो समृद्धि और प्राकृतिक सद्भाव का प्रतीक है।",
    material: "Handmade Rag Paper, Plant Indigo, Turmeric Pigment",
    technique: "Fine Line Kachni Style with Bamboo Nib",
    care_instructions: "Frame under glass to protect from direct sunlight and humidity.",
    price: 3200,
    stock: 2,
    status: "published",
    ai_generated: true,
    published_at: "2026-10-14T12:00:00Z",
    images: [
      { id: 2, url: "https://images.unsplash.com/photo-1579783902614-a3fb3927b675?w=800", is_primary: true, order_index: 0 },
    ],
    translations: [
      { id: 13, language: "en", title: "Madhubani Tree of Life Mithila Painting", description: "Intricate symbolic Tree of Life canvas embodying spiritual harmony and prosperity." },
      { id: 14, language: "hi", title: "मधुबनी जीवन वृक्ष मिथिला चित्रकला", description: "कचनी शैली में निर्मित मधुबनी जीवन वृक्ष, जो समृद्धि और प्राकृतिक सद्भाव का प्रतीक है।" },
      { id: 15, language: "mr", title: "मधुबनी जीवन वृक्ष मिथिला चित्रकला", description: "बांबूच्या टोकदार काडीने रेखाटलेली अस्सल मधुबनी जीवन वृक्षाची चित्रकृती." },
    ],
    artisan: SAMPLE_ARTISANS[1],
  },
  {
    id: 3,
    artisan_id: 3,
    category_id: 4,
    title_en: "Channapatna Eco-Friendly Wooden Stacking Toy",
    description_en: "Safe, smooth non-toxic wooden nesting toys for children hand-lathed from Wrightia tinctoria (Aale mara) wood and polished with pure beeswax and vegetable colors.",
    title_hi: "चन्नपटना पर्यावरण अनुकूल लकड़ी का खिलौना",
    description_hi: "शुद्ध हाथी लकड़ी और प्राकृतिक वनस्पति रंगों से बना सुरक्षित और विष-मुक्त पारंपरिक खिलौना।",
    material: "Ivory Wood (Aale Mara), Natural Vegetable Lacquer, Beeswax",
    technique: "Traditional Lathe Turning & Friction Lacquering",
    care_instructions: "Wipe clean with a damp cloth. Do not soak in water.",
    price: 650,
    stock: 12,
    status: "published",
    ai_generated: true,
    published_at: "2026-10-16T15:00:00Z",
    images: [
      { id: 3, url: "https://images.unsplash.com/photo-1566576912321-d58ddd7a6088?w=800", is_primary: true, order_index: 0 },
    ],
    translations: [
      { id: 16, language: "en", title: "Channapatna Eco-Friendly Wooden Stacking Toy", description: "Safe, smooth non-toxic wooden nesting toys for children." },
      { id: 17, language: "hi", title: "चन्नपटना पर्यावरण अनुकूल लकड़ी का खिलौना", description: "शुद्ध लकड़ी और प्राकृतिक रंगों से बना सुरक्षित खिलौना।" },
      { id: 18, language: "kn", title: "ಚನ್ನಪಟ್ಟಣ ಪರಿಸರ ಸ್ನೇಹಿ ಮರದ ಆಟಿಕೆ", description: "ನೈಸರ್ಗಿಕ ತರಕಾರಿ ಬಣ್ಣಗಳನ್ನು ಬಳಸಿ ಸಾಂಪ್ರದಾಯಿಕ ಲೇತ್‌ನಲ್ಲಿ ತಯಾರಿಸಿದ ಸುರಕ್ಷಿತ ಆಟಿಕೆ." },
    ],
    artisan: SAMPLE_ARTISANS[2],
  },
  {
    id: 4,
    artisan_id: 1,
    category_id: 1,
    title_en: "Terracotta Handcrafted Long-Neck Water Pitcher",
    description_en: "Hand-thrown porous terracotta pitcher naturally keeping water cool through evaporative micro-cooling.",
    title_hi: "हस्तनिर्मित पारंपरिक मिट्टी की सुराही",
    description_hi: "प्राकृतिक नदी की मिट्टी से चाक पर गढ़ी गई सुराही जो पानी को ठंडा रखती है।",
    material: "Riverbed Terracotta Clay",
    technique: "Potter's Wheel Shaping",
    care_instructions: "Rinse with plain water before first use.",
    price: 550,
    stock: 7,
    status: "published",
    ai_generated: true,
    published_at: "2026-10-15T09:00:00Z",
    images: [
      { id: 4, url: "https://images.unsplash.com/photo-1578749556568-bc2c40e68b61?w=800", is_primary: true, order_index: 0 },
    ],
    translations: [
      { id: 19, language: "en", title: "Terracotta Handcrafted Long-Neck Water Pitcher", description: "Hand-thrown porous terracotta pitcher naturally keeping water cool." },
      { id: 20, language: "hi", title: "हस्तनिर्मित पारंपरिक मिट्टी की सुराही", description: "प्राकृतिक नदी की मिट्टी से चाक पर गढ़ी गई सुराही।" },
      { id: 21, language: "mr", title: "हातमातीची पारंपरिक सुरई", description: "नैसर्गिक नदीच्या मातीपासून चाकावर घडवलेली सुरई." },
    ],
    artisan: SAMPLE_ARTISANS[0],
  },
];
