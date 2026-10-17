"""KalaSathi AI Microservice Application."""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import ai_settings
from app.routers.image import router as image_router
from app.routers.speech import router as speech_router
from app.routers.catalog import router as catalog_router
from app.routers.pricing import router as pricing_router
from app.routers.translate import router as translate_router

app = FastAPI(
    title=ai_settings.PROJECT_NAME,
    version="1.0.0",
    description="Microservice providing AI Studio (Image enhancement), Speech (ASR/TTS in 12 languages), Multimodal Cataloging, and Smart Fair Pricing for KalaSathi.",
    docs_url="/docs",
    redoc_url="/redoc",
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include AI routers
app.include_router(image_router)
app.include_router(speech_router)
app.include_router(catalog_router)
app.include_router(pricing_router)
app.include_router(translate_router)


@app.get("/", tags=["Health"])
@app.get("/health", tags=["Health"])
async def ai_health():
    return {
        "status": "healthy",
        "service": "kalasathi-ai",
        "mock_mode": ai_settings.AI_MOCK_MODE,
        "supported_languages_count": 12,
    }
