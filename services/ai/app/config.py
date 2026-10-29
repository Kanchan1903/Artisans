"""Configuration settings for KalaSathi AI Microservice."""
from functools import lru_cache
from pydantic_settings import BaseSettings


class AISettings(BaseSettings):
    ENVIRONMENT: str = "development"
    PROJECT_NAME: str = "KalaSathi AI Service"
    PORT: int = 8001

    # AI Mock Mode (True enables mock responses with zero external API dependencies)
    AI_MOCK_MODE: bool = True

    # Gemini
    GEMINI_API_KEY: str = ""
    GEMINI_MODEL: str = "gemini-3.8-flash"

    # Bhashini / ULCA
    BHASHINI_API_KEY: str = ""
    BHASHINI_USER_ID: str = ""
    BHASHINI_PIPELINE_ENDPOINT: str = "https://meity-auth.ulca.ai/ulca/apis/v0/model/getModelsPipeline"

    # Google Cloud
    GOOGLE_APPLICATION_CREDENTIALS: str = ""

    # Storage
    MINIO_ENDPOINT: str = "localhost:9000"
    MINIO_ACCESS_KEY: str = "minioadmin"
    MINIO_SECRET_KEY: str = "minioadmin_secret"
    MINIO_BUCKET: str = "kalasathi-media"

    model_config = {"env_file": ".env", "extra": "ignore"}


@lru_cache
def get_ai_settings() -> AISettings:
    return AISettings()


ai_settings = get_ai_settings()
