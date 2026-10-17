"""Multimodal catalog generation router: transcript + image -> structured product attributes and 12-language translations."""
import base64
from pydantic import BaseModel, Field
from fastapi import APIRouter, HTTPException
from app.catalog.service import catalog_from_voice_and_image, CatalogExtractionResult

router = APIRouter(prefix="/ai", tags=["Multimodal Cataloging"])


class CatalogRequest(BaseModel):
    transcript: str = Field(..., min_length=2)
    language: str = Field(default="hi")
    image_base64: str | None = None
    clarification: str | None = None


@router.post("/catalog", response_model=CatalogExtractionResult)
async def generate_catalog(payload: CatalogRequest):
    """
    Extract structured e-commerce product fields from artisan's natural spoken voice note:
    - Title in English and Hindi
    - Short summary description & detailed storytelling descriptions
    - Material, craft technique, category slug
    - Care instructions and SEO keywords
    - Strict missing specification detection (never invents missing specs)
    - Automatically translated into all 12 Indian languages
    """
    try:
        img_bytes = None
        if payload.image_base64:
            clean_b64 = payload.image_base64.split(",")[-1]
            img_bytes = base64.b64decode(clean_b64)

        result = await catalog_from_voice_and_image(
            transcript=payload.transcript,
            image_bytes=img_bytes,
            preferred_language=payload.language,
            clarification=payload.clarification,
        )
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Catalog generation error: {str(e)}")
