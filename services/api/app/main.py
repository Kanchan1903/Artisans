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
    # Ensure MongoDB indexes exist
    try:
        from app.mongodb import init_mongo_indexes
        await init_mongo_indexes()
    except Exception:
        pass
    yield


app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    description="Backend API powering KalaSathi - bridging marginalized Indian artisans with global e-commerce buyers.",
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
)

# CORS — allow all localhost ports (dev) plus any explicit production origins in settings.
# NOTE: allow_origin_regex is intentionally removed; combining it with allow_credentials
# causes Starlette to drop preflight responses on some versions.
_cors_origins = list(settings.ALLOWED_ORIGINS)
if settings.ENVIRONMENT.lower() != "production":
    # In development, whitelist every common localhost port the browser might use
    for _port in [3000, 3001, 4000, 5173, 8000, 8080, 19006]:
        for _scheme in ("http", "https"):
            for _host in ("localhost", "127.0.0.1"):
                _o = f"{_scheme}://{_host}:{_port}"
                if _o not in _cors_origins:
                    _cors_origins.append(_o)

app.add_middleware(
    CORSMiddleware,
    allow_origins=_cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"],
)

# Static file serving for uploaded product images
uploads_dir = Path("uploads")
uploads_dir.mkdir(parents=True, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=str(uploads_dir)), name="uploads")

# Include v1 API endpoints
app.include_router(api_router, prefix=settings.API_V1_PREFIX)
app.include_router(api_router, prefix="/api")


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
