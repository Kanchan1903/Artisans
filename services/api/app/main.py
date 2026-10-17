"""KalaSathi Main FastAPI Application."""
from contextlib import asynccontextmanager
from pathlib import Path
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.config import settings
from app.database import init_db
from app.api.v1 import api_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan context manager: initializes database tables and storage."""
    # Enforce configuration security checks
    settings.validate_security()
    # Ensure database tables exist
    await init_db()
    # Ensure uploads directory exists
    uploads_path = Path("uploads")
    uploads_path.mkdir(parents=True, exist_ok=True)
    yield


app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    description="Backend API powering KalaSathi - bridging marginalized Indian artisans with global e-commerce buyers.",
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
)

# CORS middleware with strict origin regex to allow localhost & explicit domains with credentials
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_origin_regex=r"^https?://(localhost|127\.0\.0\.1)(:[0-9]+)?$",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Static file serving for uploaded product images
uploads_dir = Path("uploads")
uploads_dir.mkdir(parents=True, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=str(uploads_dir)), name="uploads")

# Include v1 API endpoints
app.include_router(api_router, prefix=settings.API_V1_PREFIX)


@app.get("/", tags=["Health"])
@app.get("/health", tags=["Health"])
async def health_check():
    """Health check endpoint."""
    return {
        "status": "healthy",
        "service": "kalasathi-api",
        "version": settings.VERSION,
        "environment": settings.ENVIRONMENT,
    }
