# KalaSathi (कलासाथी)
> **AI-Powered Mobile + Web Monorepo Connecting Marginalized Indian Artisans with Conscious Global Buyers**

[![Next.js 14](https://img.shields.io/badge/Next.js-14_App_Router-black)](https://nextjs.org)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.110-009688)](https://fastapi.tiangolo.com)
[![Flutter](https://img.shields.io/badge/Flutter-3.37-02569B)](https://flutter.dev)
[![Python 3.13](https://img.shields.io/badge/Python-3.13-blue)](https://python.org)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15-336791)](https://www.postgresql.org)
[![12 Languages](https://img.shields.io/badge/Languages-12_Indian_Scripts-orange)](https://kalasathi.bharat)

---

## 🎨 Overview

KalaSathi bridges the digital divide for rural, low-literacy Indian craftspeople. Using **only photo + voice in their native dialect**, artisans can catalog handcrafted artifacts in under 2 minutes. The AI engine automatically removes cluttered backgrounds, enhances lighting, transcribes speech, extracts craft attributes, translates them into **12 mandatory Indian languages**, and computes a guaranteed fair-trade price floor. Once published, products appear in real-time on a modern e-commerce portal where buyers can read artisan stories, view GI heritage certificates, and purchase directly.

---

## 🚀 Setup & Quickstart in Under 10 Steps

### Option A: Using Docker Compose (Recommended)

1. **Clone & enter directory**:
   ```bash
   git clone https://github.com/kalasathi/kalasathi.git
   cd KalaSathi
   ```

2. **Copy environment variables**:
   ```bash
   cp .env.example .env
   ```

3. **Start all services**:
   ```bash
   docker compose up --build
   ```

4. **Seed database with sample artisans & crafts**:
   ```bash
   docker compose exec api python -m app.seed
   ```

5. **Open portals**:
   - **Buyer E-Commerce Portal**: [http://localhost:3000](http://localhost:3000)
   - **Backend API Docs (Swagger)**: [http://localhost:8000/docs](http://localhost:8000/docs)
   - **AI Microservice Health**: [http://localhost:8001/health](http://localhost:8001/health)
   - **Admin Moderation Console**: [http://localhost:3000/admin](http://localhost:3000/admin)

---

### Option B: Running Locally without Docker

1. **Start Backend API (:8000)**:
   ```bash
   cd services/api
   python -m pip install -r requirements.txt
   python -m app.seed
   uvicorn app.main:app --port 8000 --reload
   ```

2. **Start AI Microservice (:8001)**:
   ```bash
   cd services/ai
   python -m pip install -r requirements.txt
   uvicorn app.main:app --port 8001 --reload
   ```

3. **Start Buyer Web Portal (:3000)**:
   ```bash
   cd apps/web
   npm install
   npm run dev
   ```

4. **Start Artisan Mobile App (Flutter)**:
   ```bash
   cd apps/mobile
   flutter pub get
   flutter run -d chrome  # or -d android / -d ios
   ```

---

## 🎭 End-to-End Demo Walkthrough

### 1. Artisan Voice Digitization (Marathi)
1. Open the Flutter mobile app.
2. Select **"मराठी (Marathi)"** from the 12 native script cards. Hear the warm welcome voice greeting.
3. Log in with phone `+919800000001` (OTP: `123456`).
4. Tap **"वस्तू जोडा (Add Product)"**:
   - **Smart Camera**: Point camera at the craft. Smart overlay checks lighting and guides framing.
   - **AI Studio**: Tap "Enhance". Background is instantly extracted onto a pure studio canvas (1:1 aspect ratio). Drag slider to compare Before & After.
   - **Voice Note**: Speak in Marathi: *"मी हे वारली पेंटिंग तांदळाच्या पिठाने आणि डिंकाने बांबूच्या काडीने हाताने रंगवले आहे..."*
   - **AI Cataloging**: Voice is transcribed, structured, and translated into all 12 languages.
   - **Pricing Assistant**: AI calculates cost floor ($₹\text{Materials} + \text{Hours} \times ₹85/\text{hr}$). Shows Cost Floor (₹1,400), Suggested Market (₹1,800), and Premium (₹2,200). Tap to accept ₹1,800.
5. Tap **"Publish (प्रकाशित करा)"**.

### 2. Instant Live Web E-Commerce Appearance
1. Open [http://localhost:3000](http://localhost:3000).
2. The real-time Server-Sent Events (SSE) notification banner updates immediately with the newly published Warli painting!
3. Click on the product:
   - Toggle the **12-Language Switcher** pill: switch between English, Hindi, and Marathi to read the localized description.
   - Inspect the verified Artisan Story Card and GI heritage badge.

### 3. Buyer Checkout & Real-time Mobile Push
1. Click **"Buy Now"** or **"Add to Cart"** and proceed to checkout.
2. Enter delivery address in Pune, select **Razorpay (Simulated Test Mode)**, and confirm.
3. The artisan's mobile app immediately chimes with a real-time order notification:
   > *"नवीन ऑर्डर मिळाली! ₹1,800 / New Order Received!"*
4. Artisan can transition the status in the mobile app: **Accepted $\rightarrow$ Packed $\rightarrow$ Shipped**.
5. The buyer's live order tracking stepper updates synchronously!

---

## 🌐 12 Mandatory Indian Languages & Provider Matrix

| Code | Script | Language | Bhashini (ULCA) | Google Cloud | KalaSathi Zero-Key Engine | Web 12-Lang Catalog |
| :--- | :--- | :--- | :---: | :---: | :---: | :---: |
| `en` | English | English | ✅ Full (ASR/TTS) | ✅ Full (ASR/TTS) | ✅ Full (ASR/TTS) | ✅ Full Translations |
| `hi` | हिन्दी | Hindi | ✅ Full (ASR/TTS) | ✅ Full (ASR/TTS) | ✅ Full (ASR/TTS) | ✅ Full Translations |
| `mr` | मराठी | Marathi | ✅ Full (ASR/TTS) | ✅ Full (ASR/TTS) | ✅ Full (ASR/TTS) | ✅ Full Translations |
| `bn` | বাংলা | Bengali | ✅ Full (ASR/TTS) | ✅ Full (ASR/TTS) | ✅ Full (ASR/TTS) | ✅ Full Translations |
| `ta` | தமிழ் | Tamil | ✅ Full (ASR/TTS) | ✅ Full (ASR/TTS) | ✅ Full (ASR/TTS) | ✅ Full Translations |
| `te` | తెలుగు | Telugu | ✅ Full (ASR/TTS) | ✅ Full (ASR/TTS) | ✅ Full (ASR/TTS) | ✅ Full Translations |
| `kn` | ಕನ್ನಡ | Kannada | ✅ Full (ASR/TTS) | ✅ Full (ASR/TTS) | ✅ Full (ASR/TTS) | ✅ Full Translations |
| `ml` | മലയാളം | Malayalam | ✅ Full (ASR/TTS) | ✅ Full (ASR/TTS) | ✅ Full (ASR/TTS) | ✅ Full Translations |
| `gu` | ગુજરાતી | Gujarati | ✅ Full (ASR/TTS) | ✅ Full (ASR/TTS) | ✅ Full (ASR/TTS) | ✅ Full Translations |
| `pa` | ਪੰਜਾਬੀ | Punjabi | ✅ Full (ASR/TTS) | ✅ Full (ASR/TTS) | ✅ Full (ASR/TTS) | ✅ Full Translations |
| `or` | ଓଡ଼ିଆ | Odia | ✅ Full (ASR/TTS) | ⚠️ Experimental v1 | ✅ Full (ASR/TTS) | ✅ Full Translations |
| `as` | অসমীয়া | Assamese | ✅ Full (ASR/TTS) | ⚠️ Experimental v1 | ✅ Full (ASR/TTS) | ✅ Full Translations |

> [!NOTE]
> **Provider Support Disclosure**: Bhashini (National Language Translation Mission) and the KalaSathi Zero-Key Mock Engine fully support all 12 scheduled Indian languages for both Speech Recognition (ASR) and Text-to-Speech (TTS). Google Cloud Speech-to-Text v1 has standard support for 10 languages, with Odia (`or`) and Assamese (`as`) categorized as experimental in standard Cloud Speech v1. KalaSathi automatically inspects provider capabilities via `verify_language_support()` and performs seamless fallback if a provider lacks support for the requested language.

---

## 🔑 Pre-Seeded Demo Credentials

| Role | Name | Phone | Craft / Location |
| :--- | :--- | :--- | :--- |
| **Artisan (Marathi)** | Sunita Bai Sonawane | `+919800000001` | Warli Painting, Palghar, Maharashtra |
| **Artisan (Hindi)** | Rameshwar Chitrakar | `+919800000002` | Madhubani Art, Ranti, Bihar |
| **Artisan (Kannada)** | Basavaraju Gudigar | `+919800000003` | Channapatna Toys, Karnataka |
| **Buyer** | Pooja Kulkarni | `+919820000001` | Pune, Maharashtra |
| **Admin** | Guild Administrator | `+919999999999` | All India Trust & Moderation |

*Note: In development and test mode, OTP is `123456` or mocked.*

---

## 🧪 Comprehensive Automated Test Suites

```bash
# 1. Backend API tests (21 tests, 100% pass)
cd services/api && pytest

# 2. AI Microservice tests (16 tests, 100% pass)
cd services/ai && pytest

# 3. Mobile App tests (19 unit & widget tests, 100% pass)
cd apps/mobile && flutter test

# 4. Complete 12-Step Marathi End-to-End Workflow Verification
python scratch/test_e2e_marathi_complete_workflow.py

# 5. Systematic 12-Language ASR/TTS/Translation Verification
python scratch/test_all_12_languages.py

# 6. Next.js Web production build (9 routes, 0 lint/type errors)
cd apps/web && npm run build
```

---

## ⚙️ Environment Variables Reference

| Variable | Service | Description | Default / Example |
| :--- | :--- | :--- | :--- |
| `DATABASE_URL` | API | Database connection string (PostgreSQL or SQLite) | `sqlite+aiosqlite:///./kalasathi.db` |
| `JWT_SECRET` | API | Secret key for signing artisan and buyer JWT tokens | `kalasathi-super-secret-jwt-key` |
| `AI_SERVICE_URL` | API | Internal URL for the AI microservice | `http://127.0.0.1:8001` |
| `AI_MOCK_MODE` | AI | Enables zero-key fallback engine for offline testing | `true` |
| `BHASHINI_API_KEY` | AI | Bhashini ULCA API key for all 12 Indian languages | Optional in mock mode |
| `BHASHINI_USER_ID` | AI | Bhashini ULCA User ID | Optional in mock mode |
| `BHASHINI_PIPELINE_ID`| AI | Bhashini ULCA Pipeline ID | Optional in mock mode |
| `GOOGLE_APPLICATION_CREDENTIALS` | AI | Path to Google Cloud Service Account JSON | Optional in mock mode |
| `RAZORPAY_KEY_ID` | API / Web | Razorpay payment gateway test key | `rzp_test_kalasathi` |
| `RAZORPAY_KEY_SECRET` | API | Razorpay secret key | `rzp_test_secret` |
| `NEXT_PUBLIC_API_URL` | Web | Public API base URL consumed by browser client | `http://localhost:8000/api/v1` |

---

## 🏛️ Monorepo Structure

```
KalaSathi/
├── apps/
│   ├── mobile/         # Flutter app: 12-language ARB, 5-step wizard, 12 studio variations, transparent pricing
│   └── web/            # Next.js 14 App Router: 12-lang switcher, faceted search, cart, checkout, admin
├── services/
│   ├── api/            # FastAPI, SQLAlchemy, Alembic, SQLite/Postgres, JWT auth, earnings dashboard, orders
│   └── ai/             # FastAPI :8001: 12 studio variations generator, Bhashini/Google speech, cataloging, ML pricing
├── scratch/            # End-to-end integration test scripts (12-step Marathi E2E, 12-language suite)
├── docs/
│   ├── ARCHITECTURE.md # Full architecture, sequence diagrams, ER model, language pipeline
│   └── PLAN.md         # Phased execution plan & specifications
├── docker-compose.yml  # Multi-container orchestration (postgres, redis, minio, api, ai, web)
└── README.md
```
#   A r t i s a n s  
 