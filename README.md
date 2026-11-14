<div align="center">

# 🎨 KalaSathi — कलासाथी

### AI-Powered Ethical E-Commerce for Indian Artisans

*Empowering rural Indian master artisans to digitize, price, and sell their handcrafted creations using voice and photo — in 12 Indian languages, with zero middlemen.*

[![Next.js](https://img.shields.io/badge/Web-Next.js%2014-black?logo=next.js)](https://nextjs.org)
[![Flutter](https://img.shields.io/badge/Mobile-Flutter-02569B?logo=flutter)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/API-FastAPI-009688?logo=fastapi)](https://fastapi.tiangolo.com)
[![Python](https://img.shields.io/badge/Python-3.11%20%7C%203.13-3776AB?logo=python)](https://python.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

</div>

---

## 📖 What is KalaSathi?

KalaSathi bridges the gap between **rural Indian master artisans** and **global buyers** through seamless AI-assisted workflows and live e-commerce synchronization.

An artisan in Maharashtra, Bihar, or Rajasthan can:
1. **Photograph** their craft — and enter the dedicated **AI Product Photo Studio** where background segmentation cleanly removes clutter, offering WhatsApp-like studio backdrop options while strictly preserving every detail of the original handmade craft.
2. **Speak** naturally in their regional language (Marathi, Hindi, Bengali, Tamil, etc.) to the **Multilingual Voice Description Agent**, generating verified, professional e-commerce product titles and descriptions grounded only in true statements.
3. **Dynamic AI Pricing Agent** conducts live market research on comparable handmade products, calculating fair recommended prices based on material costs, labor, and profit, while allowing full manual customization and regional voice adjustments.
4. **Publish** in one tap — automatically synchronizing newly approved creations to the live **KalaSathi E-Commerce Web Storefront** without mock data or duplicate records.
5. **Artisan-Controlled Buyer Inquiry & Order System** — Buyers on the website can enquire directly ("Contact Artisan / Enquire About Product"). The artisan receives instant notifications, reviews buyer details, and chooses to Accept, Reject, Schedule Contact, WhatsApp/Call the buyer, negotiate, and confirm agreed orders.

No English literacy required. Zero middlemen commissions. Complete artisan sovereignty.

---

## 🚀 Live Deployments

- **Frontend E-Commerce Website (Vercel):** Connected via GitHub CI/CD on the `main` branch.
- **Backend API & PostgreSQL Database (Render):** Deployed via `render.yaml` blueprint with automated Alembic migrations on startup (`kalasathi-api.onrender.com`).

---

## 🏗️ Project Architecture

```
KalaSathi/
├── apps/
│   ├── web/              # Next.js 14 — Buyer storefront + Product detail with "Contact Artisan"
│   └── mobile/           # Flutter — Artisan mobile app (Studio, Voice Agent, Pricing, Inquiries)
├── services/
│   ├── api/              # FastAPI — Core backend (auth, products, inquiries, pricing, MongoDB/PostgreSQL)
│   └── ai/               # Python AI service (speech, image studio, pricing, translation)
├── docs/                 # Architecture & planning documents
├── render.yaml           # Render deployment configuration for API and PostgreSQL
├── docker-compose.yml    # One-command local development with MongoDB & PostgreSQL
└── .env.example          # Environment variable template
```

---

## ✨ Key Features & AI Agents

### 📸 1. AI Product Photo Studio
- Dedicated studio interface with background segmentation (`rembg` / OpenCV / CrewAI).
- WhatsApp-style background picker (Studio White, Warm Cream, Terracotta Beige, Pastel Pink, Pastel Blue, Festive Silk, Wooden Board, Custom Color Picker).
- **Strict Product Preservation:** Zero generative hallucinations or modifications to handmade textures, stitches, or colors.

### 🎙️ 2. Multilingual Voice Description Agent
- Voice recording in regional Indian languages (Marathi, Hindi, Tamil, Telugu, Bengali, Gujarati, Kannada, etc.).
- Strict grounding: preserves facts mentioned by the artisan, preventing fabricated claims.
- SEO keyword enrichment and automated English translation.

### 💰 3. Dynamic Pricing Multi-Agent System
- Live market research across e-commerce benchmarks for comparable handmade crafts.
- Cost breakdown: Materials + Artisan Labor + Packaging + Profit Margin.
- Displays comparable market price ranges (Min, Avg, Max) with verifiable sources.
- Complete manual override and regional voice feedback loop to recalculate pricing preferences.

### 🌐 4. Live E-Commerce Web Storefront Synchronization
- Approved products instantly appear on the public marketplace.
- Real-time catalog querying PostgreSQL with MongoDB document backup.
- Rich product detail views with multi-image gallery, artisan lineage storytelling, customer reviews, and Google Schema.org JSON-LD metadata.

### 📬 5. Artisan-Controlled Buyer Inquiry & Order System
- **Website Contact Form:** Buyers submit their name, phone (mobile/WhatsApp), optional email, quantity, and requirements. Automatically binds Product ID and title.
- **Instant Artisan Notification:** Alerts the maker immediately on their mobile device.
- **Artisan Freedom of Contact:** The artisan controls if, when, and how to reach the buyer:
  - *Accept Inquiry*
  - *Schedule Contact (with Date & Time picker + reminder notes)*
  - *Contact Later (keep pending)*
  - *Reject Inquiry*
  - *Direct Call / WhatsApp / Email triggers with prefilled message templates*
- **Order Confirmation:** Artisans record agreed price, quantity, and delivery terms, automatically updating stock and buyer status.

---

## 🔑 Environment Variables

Copy `.env.example` to `.env` and fill in the values:

```env
# Google AI (Gemini LLM + Vision + Speech)
GOOGLE_API_KEY=your_google_api_key

# JWT Authentication
SECRET_KEY=your_random_secret_key_min_32_chars
ACCESS_TOKEN_EXPIRE_MINUTES=10080

# Database (PostgreSQL)
DATABASE_URL=postgresql+asyncpg://kalasathi:password@localhost:5432/kalasathi

# MongoDB (JSON document storage for catalogs and inquiries)
MONGODB_URI=mongodb://localhost:27017/kalasathi
MONGODB_DB_NAME=kalasathi
MONGODB_REQUIRED=false

# Web app API URL (Vercel)
NEXT_PUBLIC_API_URL=https://kalasathi-api.onrender.com/api/v1
```

---

## 🛠️ Deployment Guide

### Deploying Backend to Render
1. Go to your [Render Dashboard](https://dashboard.render.com).
2. Click **New +** $\rightarrow$ **Blueprint**.
3. Connect your GitHub repository `Kanchan1903/Artisans`.
4. Render detects `render.yaml` and provisions:
   - **`kalasathi-db`** (PostgreSQL Database)
   - **`kalasathi-api`** (FastAPI Web Service with Docker runtime)
5. On deployment, Render automatically executes database migrations via `alembic upgrade head`.

### Deploying Frontend to Vercel
1. Go to your [Vercel Dashboard](https://vercel.com).
2. Select your repository `Kanchan1903/Artisans`.
3. Set **Root Directory** to `apps/web`.
4. Set Environment Variable:
   - `NEXT_PUBLIC_API_URL`: `https://kalasathi-api.onrender.com/api/v1`
5. Click **Deploy**. Vercel will build and host your storefront automatically on push to `main`.

---

## 🌐 API Reference

Interactive API documentation is accessible at `http://localhost:8000/docs` (or your Render URL `/docs`).

| Method & Route | Description |
|---|---|
| `POST /api/v1/auth/otp/send` | Send OTP to mobile phone |
| `POST /api/v1/auth/otp/verify` | Verify OTP and issue JWT access token |
| `GET /api/v1/products` | Browse public catalog (category, search filters) |
| `POST /api/v1/products` | Create draft handcrafted creation |
| `POST /api/v1/products/{id}/publish` | Publish approved product to web storefront |
| `POST /api/v1/inquiries` | Buyer submits inquiry with name, phone, email, and quantity |
| `GET /api/v1/inquiries/artisan/me` | Artisan inbox: all received inquiries |
| `PATCH /api/v1/inquiries/{id}/status` | Artisan updates status (accept, schedule, reject, etc.) |
| `POST /api/v1/inquiries/{id}/confirm-order` | Artisan confirms agreed order details |
| `POST /api/v1/ai/pricing/recommendation` | Dynamic multi-agent market price research |
| `POST /api/v1/ai/pricing/challenge` | Recalculate price using artisan's voice feedback |

---

## 🧪 Testing

### Backend API tests
```bash
python -m pytest services/api/tests/ -v
```

### Flutter tests
```bash
cd apps/mobile
flutter test
```

### Web Storefront Build
```bash
npm --prefix apps/web run build
```

---

<div align="center">

**Made with ❤️ for Indian Artisans**

*"Every handcrafted creation represents a living heritage."*

[🌐 Web App](https://kalasathi.bharat) · [📚 API Docs](https://kalasathi-api.onrender.com/docs) · [🐛 Issues](https://github.com/Kanchan1903/Artisans/issues)

</div>
