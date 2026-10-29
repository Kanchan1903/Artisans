"""Application configuration using pydantic-settings."""
from functools import lru_cache
from pydantic_settings import BaseSettings
from pydantic import AnyUrl


class Settings(BaseSettings):
    # App
    ENVIRONMENT: str = "development"
    PROJECT_NAME: str = "KalaSathi API"
    VERSION: str = "1.0.0"
    API_V1_PREFIX: str = "/api/v1"
    CURRENCY_CODE: str = "INR"

    # Database
    DATABASE_URL: str = "postgresql+asyncpg://kalasathi:kalasathi_secret@localhost:5432/kalasathi"

    # Redis
    REDIS_URL: str = "redis://:redis_secret@localhost:6379/0"
    REDIS_PASSWORD: str = "redis_secret"

    # JWT
    JWT_SECRET_KEY: str = "change_me_in_production"
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRE_MINUTES: int = 10080  # 7 days

    # MinIO / S3
    MINIO_ENDPOINT: str = "localhost:9000"
    MINIO_ACCESS_KEY: str = "minioadmin"
    MINIO_SECRET_KEY: str = "minioadmin_secret"
    MINIO_BUCKET: str = "kalasathi-media"
    MINIO_USE_SSL: bool = False

    # AI Service
    AI_SERVICE_URL: str = "http://localhost:8001"
    AI_MOCK_MODE: bool = True

    # CrewAI AMP (product image processing). Token stays on the backend only.
    CREWAI_API_BASE_URL: str = "https://karigarai-product-image-processing-agent-v1-4812b293.crewai.com"
    CREWAI_BEARER_TOKEN: str = ""

    # MongoDB
    MONGODB_URI: str = "mongodb://localhost:27017/kalasathi"
    MONGODB_DB_NAME: str = "kalasathi"
    MONGODB_REQUIRED: bool = True

    # Cloudinary (optional image storage fallback/alternative)
    CLOUDINARY_CLOUD_NAME: str = ""
    CLOUDINARY_API_KEY: str = ""
    CLOUDINARY_API_SECRET: str = ""

    # OTP
    OTP_PROVIDER: str = "mock"  # mock | twilio | msg91
    OTP_EXPIRE_MINUTES: int = 10
    TWILIO_ACCOUNT_SID: str = ""
    TWILIO_AUTH_TOKEN: str = ""
    TWILIO_FROM_NUMBER: str = ""

    # Firebase FCM
    FIREBASE_SERVICE_ACCOUNT_PATH: str = ""

    # Network & Public URLs
    PUBLIC_API_URL: str = "http://localhost:8000"
    MINIO_PUBLIC_URL: str = "http://localhost:9000"

    # CORS
    ALLOWED_ORIGINS: list[str] = [
        "http://localhost:3000",
        "http://localhost:8000",
        "http://localhost:8080",
        "http://127.0.0.1:3000",
        "http://127.0.0.1:8000",
        "http://127.0.0.1:8080",
    ]

    model_config = {"env_file": ".env", "extra": "ignore"}

    def validate_security(self):
        """Enforce strict security in production environments."""
        if self.ENVIRONMENT.lower() == "production":
            if self.JWT_SECRET_KEY in ("change_me_in_production", "", "secret"):
                raise ValueError("SECURITY ALERT: JWT_SECRET_KEY must be set securely in production.")


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
