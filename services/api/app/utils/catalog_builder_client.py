"""CrewAI AMP client for the catalog-builder deployment."""

from app.config import settings
from app.utils.crewai_client import CrewAIClient


catalog_builder_client = CrewAIClient(
    base_url=settings.CATALOG_BUILDER_API_BASE_URL,
    bearer_token=settings.catalog_builder_bearer_token,
)
