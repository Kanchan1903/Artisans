<div align="center">

# 🎨 KalaSathi — कलासाथी

### AI-Powered Ethical E-Commerce for Indian Artisans

*Empowering rural Indian master artisans to digitize and sell their handcrafted creations using only voice and photo — in 12 Indian languages, with zero middlemen.*

[![Next.js](https://img.shields.io/badge/Web-Next.js%2014-black?logo=next.js)](https://nextjs.org)
[![Flutter](https://img.shields.io/badge/Mobile-Flutter-02569B?logo=flutter)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/API-FastAPI-009688?logo=fastapi)](https://fastapi.tiangolo.com)
[![Python](https://img.shields.io/badge/AI-Python%203.13-3776AB?logo=python)](https://python.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

</div>

---

## 📖 What is KalaSathi?

KalaSathi bridges the gap between **rural Indian artisans** and **global buyers** using AI.

An artisan in Palghar, Maharashtra can:
1. **Speak** a product description in Marathi into a mobile app
2. **Photograph** their craft — and AI removes the background and generates 12 studio-quality variations
3. **Get a fair price** calculated from actual material costs, labour hours, and real market comparables
4. **Publish** their product listing to the web storefront — translated into all 12 Indian languages — in under 5 minutes
5. **Receive instant notifications** on their phone when a buyer places an order

No typing. No English required. No middlemen taking a cut.

---

## 🏗️ Project Architecture

```
KalaSathi/
├── apps/
│   ├── web/              # Next.js 14 — Buyer storefront + Artisan/Admin web portal
│   └── mobile/           # Flutter — Artisan mobile app (voice, camera, orders)
├── services/
│   ├── api/              # FastAPI — Core backend (auth, products, orders, earnings)
│   └── ai/               # Python AI service (speech, image, pricing, translation)
├── docs/                 # Architecture & planning documents
├── docker-compose.yml    # One-command local development
└── .env.example          # Environment variable template
```

---

## ✨ Key Features

### 🎤 Voice Catalog — 12 Indian Languages
Artisans describe their product naturally in their mother tongue. The system transcribes, structures, and translates the listing into all 12 supported languages automatically.

**Supported:** English · Hindi · Marathi · Bengali · Tamil · Telugu · Kannada · Malayalam · Gujarati · Punjabi · Odia · Assamese

### 📸 AI Image Studio
Upload one raw photo → get 12 studio-quality product variations: white background, gradient, natural light, detail close-up, lifestyle setting, and more. Powered by Google Gemini Vision.

### 💰 Intelligent Fair Pricing
Three-tier pricing calculator:
- **Minimum** — covers materials + labour + packaging (statutory wage floor guaranteed)
- **Suggested** — based on real comparable market products
- **Premium** — for GI-tagged or rare craft techniques

### 🛍️ E-Commerce Publishing
One-tap publish from the mobile app. The product appears live on the web storefront instantly, with all translations attached, inventory tracked, and artisan ID preserved.

### 📦 Orders & Notifications
- Buyers place orders on the web → artisan receives an **instant push notification** (FCM) on their mobile
- Real-time order status: Placed → Accepted → Packed → Shipped → Delivered
- Earnings dashboard with monthly breakdown and payout status

### 🔐 Role-Based Authentication
- **Buyers** — Browse, wishlist, cart, checkout, order tracking
- **Artisans** — Voice catalog, image studio, pricing, publish, orders, earnings
- **Admins** — Artisan verification queue, product moderation, fulfillment oversight
- OTP-based phone login (no passwords). Dev mode shows mock OTP for easy testing.

---

## 🖥️ Web App Pages

| Route | Description |
|---|---|
| `/` | Buyer homepage with hero, product grid, artisan spotlight, live SSE notifications |
| `/products` | Full catalog with category, state, price, and search filters |
| `/products/[id]` | Product detail with image gallery, artisan bio, add-to-cart |
| `/artisans/[id]` | Artisan public profile with story and all their products |
| `/cart` | Shopping cart with quantity controls |
| `/checkout` | Checkout with Razorpay (UPI/Cards) and COD options |
| `/orders/[id]` | Order tracking stepper with live status |
| `/login` | OTP login — role picker → phone → 6-digit OTP |
| `/signup` | New account registration for buyers and artisans |
| `/account` | Buyer dashboard — orders, addresses, wishlist |
| `/artisan/dashboard` | Artisan web dashboard — overview, orders, products, earnings |
| `/admin` | Admin console — artisan queue, product moderation, fulfillment |

---

## 📱 Mobile App Screens

| Screen | Description |
|---|---|
| Onboarding | Language selection + OTP login |
| Home | Welcome card, earnings summary, quick-action tiles, offline sync indicator |
| Add Product Wizard | Voice record → transcribe → catalog → image studio → pricing → publish |
| My Products | Inventory management — edit stock, delist, re-publish |
| Orders | Incoming orders with accept/pack/ship actions |
| Earnings | Monthly income breakdown, pending payouts, bank details |
| Settings | Language switcher, notification prefs, profile, logout |

---

## 🚀 Getting Started

### Prerequisites

- Node.js 18+
- Python 3.11+
- Flutter 3.x SDK
- Git

### 1. Clone the repository

```bash
git clone https://github.com/Kanchan1903/Artisans.git
cd Artisans
```

### 2. Set up environment variables

```bash
cp .env.example .env
# Edit .env with your API keys (see Environment Variables section below)
```

### 3. Start the backend API

```bash
cd services/api
pip install -r requirements.txt
python -m app.seed          # Seed demo artisans and products
uvicorn app.main:app --reload --port 8000
```

API docs available at: `http://localhost:8000/docs`

### 4. Start the AI service

```bash
cd services/ai
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8001
```

### 5. Start the web app

```bash
cd apps/web
npm install
npm run dev
```

Web app available at: `http://localhost:3000`

### 6. Run the Flutter mobile app

```bash
cd apps/mobile
flutter pub get
flutter run
```

#### Connect a physical Android phone to the local API

The default `127.0.0.1` address refers to the phone itself when Flutter runs on a physical device. Start the API and its required services first (`docker compose up -d postgres redis mongo minio api` from the repository root), then use either:

- **USB:** `adb reverse tcp:8000 tcp:8000`, then run `flutter run`.
- **Same Wi-Fi:** run `flutter run --dart-define=API_URL=http://<laptop-ip>:8000/api/v1`. Find the laptop's Wi-Fi IPv4 address with `ipconfig`; allow port 8000 through the laptop firewall for the private network if prompted.

#### Enable real CrewAI image processing

Set these values in the repository-root `.env` file, which is read by Docker Compose:

```env
AI_MOCK_MODE=false
CREWAI_BEARER_TOKEN=<your CrewAI AMP bearer token>
```

Keep the token on the backend; never put it in Flutter or a `--dart-define`. CrewAI must be able to fetch the uploaded original image. Use a publicly reachable **HTTPS** `MINIO_PUBLIC_URL` (or configure `PUBLIC_API_URL` to serve the image over HTTPS), and configure the storage service/proxy so the returned image URL can be fetched from the public internet. Localhost, private LAN, and plain HTTP image URLs are rejected by the workflow. With mock mode enabled or the CrewAI token missing, real image processing will not run.

### One-command Docker setup (optional)

```bash
docker-compose up --build
```

---

## 🔑 Environment Variables

Copy `.env.example` to `.env` and fill in the values:

```env
# Google AI (Gemini LLM + Vision + Speech)
GOOGLE_API_KEY=your_google_api_key

# Sarvam AI — Indian language ASR (preferred for regional languages)
SARVAM_API_KEY=your_sarvam_api_key

# JWT Authentication
SECRET_KEY=your_random_secret_key_min_32_chars
ACCESS_TOKEN_EXPIRE_MINUTES=10080

# Database (defaults to SQLite for local dev)
DATABASE_URL=sqlite+aiosqlite:///./kalasathi.db
# For PostgreSQL: postgresql+asyncpg://user:pass@localhost/kalasathi

# MongoDB stores queryable image-job output JSON
MONGODB_URI=mongodb://localhost:27017/kalasathi
MONGODB_DB_NAME=kalasathi
MONGODB_REQUIRED=true

# Razorpay (payment gateway)
RAZORPAY_KEY_ID=your_razorpay_key_id
RAZORPAY_KEY_SECRET=your_razorpay_key_secret

# Firebase Cloud Messaging (push notifications)
FCM_SERVER_KEY=your_fcm_server_key

# Web app API URL
NEXT_PUBLIC_API_URL=http://localhost:8000/api/v1
```

> **Note:** In development mode, the backend returns the OTP directly in the API response (`mock_code` field). Use `123456` as a universal test OTP for any phone number.

Start MongoDB before the API when `MONGODB_REQUIRED=true` (for example, `docker compose up mongo`). Direct local API runs use `mongodb://localhost:27017/kalasathi`; Docker Compose uses `MONGODB_URI_DOCKER` (default `mongodb://mongo:27017/kalasathi`). Image-job results are saved in the `image_jobs.output_json` document field and can be queried by `job_id`:

```javascript
db.image_jobs.findOne({ job_id: "<job-id>" }, { _id: 0, output_json: 1 })
```

The artisan API also exposes the same saved JSON at `GET /api/v1/image-jobs/{job_id}/output`. Apply SQL migrations with `cd services/api && alembic upgrade head`.

---

## 🛠️ Tech Stack

### Web (`apps/web`)
| Technology | Purpose |
|---|---|
| Next.js 14 (App Router) | React framework, SSR, routing |
| TypeScript | Type safety |
| Tailwind CSS | Styling |
| Lucide React | Icons |
| React Context | Auth state, cart state |

### Mobile (`apps/mobile`)
| Technology | Purpose |
|---|---|
| Flutter | Cross-platform mobile (Android + iOS) |
| Dart | Language |
| Provider | State management |
| `record` package | Audio recording for voice catalog |
| `image_picker` | Camera/gallery for product photos |
| `shared_preferences` | Offline storage and auth persistence |

### Backend API (`services/api`)
| Technology | Purpose |
|---|---|
| FastAPI | REST API framework |
| SQLAlchemy (async) | ORM |
| Alembic | Database migrations |
| SQLite / PostgreSQL | Database |
| JWT (python-jose) | Authentication tokens |
| Firebase Admin SDK | Push notifications |
| Server-Sent Events | Real-time product publish stream |

### AI Service (`services/ai`)
| Technology | Purpose |
|---|---|
| Google Gemini 1.5 Flash | Catalog generation, image enhancement |
| Sarvam AI | Indian language speech-to-text (ASR) |
| Google Speech-to-Text | ASR fallback for all languages |
| Google Cloud Translation | Multi-language product translation |

---

## 🌐 API Reference

Full interactive docs at `http://localhost:8000/docs` (Swagger UI).

Key endpoint groups:

| Prefix | Description |
|---|---|
| `POST /api/v1/auth/otp/send` | Send OTP to phone number |
| `POST /api/v1/auth/otp/verify` | Verify OTP, get JWT token |
| `GET /api/v1/products` | List products (with filters) |
| `POST /api/v1/products` | Create product (artisan auth) |
| `POST /api/v1/products/{id}/publish` | Publish product to storefront |
| `POST /api/v1/orders` | Place an order (buyer auth) |
| `GET /api/v1/orders/artisan` | Get artisan's incoming orders |
| `GET /api/v1/earnings/summary` | Artisan earnings summary |
| `POST /api/v1/ai/voice/transcribe` | Transcribe voice in given language |
| `POST /api/v1/ai/catalog/generate` | Generate product listing from transcript |
| `POST /api/v1/ai/image/enhance` | Generate 12 studio image variations |
| `POST /api/v1/ai/pricing/calculate` | Calculate 3-tier fair pricing |
| `GET /api/v1/events/stream` | SSE stream for real-time updates |

---

## 🧪 Testing

### Backend API tests
```bash
cd services/api
pytest tests/ -v
```

### AI service tests
```bash
cd services/ai
pytest tests/ -v
```

### Flutter tests
```bash
cd apps/mobile
flutter test
```

### Web type check
```bash
cd apps/web
npx tsc --noEmit
```

---

## 🗺️ Roadmap

- [ ] Razorpay live payment integration
- [ ] SMS OTP delivery (Twilio / MSG91)
- [ ] Artisan GI-tag certificate upload and verification
- [ ] Buyer reviews and ratings
- [ ] WhatsApp order status notifications
- [ ] Multi-vendor checkout (single cart, multiple artisans)
- [ ] Analytics dashboard for artisan cluster coordinators
- [ ] Android APK build and Play Store listing

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Commit your changes: `git commit -m 'feat: add your feature'`
4. Push to the branch: `git push origin feature/your-feature`
5. Open a Pull Request

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgements

- Built with deep respect for India's indigenous craft traditions and the artisans who preserve them
- Inspired by the vision of zero-middlemen, fair-wage, digital inclusion for rural India
- Powered by Google Gemini AI, Sarvam AI, and the open-source community

---

<div align="center">

**Made with ❤️ for Indian Artisans**

*"Every purchase is a vote for a living cultural heritage."*

[🌐 Web App](http://localhost:3000) · [📚 API Docs](http://localhost:8000/docs) · [🐛 Report Bug](https://github.com/Kanchan1903/Artisans/issues)

</div>
