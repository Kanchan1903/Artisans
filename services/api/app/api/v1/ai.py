"""AI Router for KalaSathi Backend API.
Proxies and coordinates AI tasks with the dedicated AI microservice:
- Voice transcription (ASR)
- Voice synthesis (TTS)
- Multimodal catalog extraction (Never invents missing specs; generates 12-language translations)
- Image studio background removal & lighting correction
- Smart pricing assistant
- Provider status and language capability inspection
"""
import base64
import httpx
from pydantic import BaseModel, Field
from fastapi import APIRouter, UploadFile, File, Form, HTTPException, status
from app.config import settings

router = APIRouter(prefix="/ai", tags=["AI Integration"])

SUPPORTED_LANGUAGES = ["en", "hi", "mr", "bn", "ta", "te", "kn", "ml", "gu", "pa", "or", "as"]


class TTSPayload(BaseModel):
    text: str = Field(..., min_length=1)
    language: str = Field(default="hi")
    simulate_failure: bool = False


class CatalogPayload(BaseModel):
    transcript: str = Field(..., min_length=2)
    language: str = Field(default="hi")
    image_base64: str | None = None
    clarification: str | None = None


class PricePayload(BaseModel):
    craft_category: str = Field(default="Pottery")
    material_cost: float = Field(..., ge=0.0)
    labor_hours: float = Field(..., ge=0.01)
    hourly_rate: float = Field(default=85.0, ge=0.0)
    packaging_cost: float = Field(default=30.0, ge=0.0)
    shipping_cost: float = Field(default=60.0, ge=0.0)
    platform_fee_percent: float = Field(default=8.0, ge=0.0, le=50.0)
    material: str | None = None
    technique: str | None = None
    dimensions: str | None = None
    experience_years: int = 10
    complexity_score: int = 6
    language: str = "en"


class PriceOverridePayload(BaseModel):
    override_price: float = Field(..., ge=0.0)
    cost_floor: float = Field(..., ge=0.0)
    language: str = Field(default="en")


@router.get("/providers")
async def get_ai_providers():
    """Returns runtime provider status and language capability matrices from the AI microservice."""
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            res = await client.get(f"{settings.AI_SERVICE_URL}/ai/providers")
            if res.status_code == 200:
                return res.json()
    except Exception:
        pass

    # Resilient fallback if AI microservice is starting or in isolated test
    return {
        "status": "success",
        "supported_languages": SUPPORTED_LANGUAGES,
        "providers": {
            "bhashini": {"name": "Bhashini (ULCA)", "has_credentials": False, "is_active": False},
            "google": {"name": "Google Cloud", "has_credentials": False, "is_active": False},
            "mock": {"name": "KalaSathi Resilient Mock", "has_credentials": True, "is_active": True},
        },
    }


@router.post("/transcribe")
async def transcribe_speech(
    file: UploadFile | None = File(None),
    language: str = Form("hi"),
    simulate_failure: bool = Form(False),
):
    """
    Transcribes artisan voice note using regional provider with verified language support.
    """
    lang = language.lower()
    if lang not in SUPPORTED_LANGUAGES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Language '{language}' is not supported. Supported: {', '.join(SUPPORTED_LANGUAGES)}",
        )

    audio_bytes = b""
    if file:
        audio_bytes = await file.read()

    try:
        files = {"file": (file.filename or "voice.wav", audio_bytes, file.content_type or "audio/wav")} if file else None
        data = {"language": lang, "simulate_failure": "true" if simulate_failure else "false"}
        async with httpx.AsyncClient(timeout=15.0) as client:
            res = await client.post(f"{settings.AI_SERVICE_URL}/ai/transcribe", files=files, data=data)
            if res.status_code == 200:
                return res.json()
            elif res.status_code == 400:
                raise HTTPException(status_code=400, detail=res.json().get("detail", "Bad Request"))
    except HTTPException:
        raise
    except Exception as e:
        pass

    # Resilient local fallback
    fallback_map = {
        "mr": "हा हाताने बनवलेला वारली कलेचा कॅनव्हास आहे. यात तांदळाचे पीठ आणि डिंकाचा नैसर्गिक रंग वापरला आहे. तयार करायला सहा तास लागले आणि साहित्याचा खर्च सुमारे दीडशे रुपये आहे.",
        "hi": "यह हस्तनिर्मित मिट्टी का घड़ा है। इसे बनाने में गंगा किनारे की काली मिट्टी का उपयोग किया गया है। चार घंटे का समय लगा और सामग्री पर लगभग अस्सी रुपये खर्च हुए।",
        "en": "This is a handmade terracotta earthen vase crafted from riverbed clay. It took 5 hours and material cost was around 100 rupees.",
    }
    return {
        "transcript": fallback_map.get(lang, fallback_map["hi"]),
        "language": lang,
        "provider_used": "mock",
        "fallback_used": True,
        "fallback_reason": "AI microservice direct proxy fallback",
    }


@router.post("/synthesize")
async def synthesize_speech(payload: TTSPayload):
    """
    Synthesizes listing description aloud in the artisan's preferred language.
    """
    lang = payload.language.lower()
    if lang not in SUPPORTED_LANGUAGES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Language '{payload.language}' is not supported. Supported: {', '.join(SUPPORTED_LANGUAGES)}",
        )

    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            res = await client.post(f"{settings.AI_SERVICE_URL}/ai/synthesize", json=payload.model_dump())
            if res.status_code == 200:
                return res.json()
    except Exception:
        pass

    # Minimal base64 WAV fallback
    import io, wave, struct
    buf = io.BytesIO()
    with wave.open(buf, "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(8000)
        samples = [int(1000 * (i % 20) / 20.0) for i in range(8000)]
        wav.writeframes(struct.pack(f"<{len(samples)}h", *samples))
    b64 = base64.b64encode(buf.getvalue()).decode("utf-8")

    return {
        "audio_base64": b64,
        "format": "audio/wav",
        "language": lang,
        "provider_used": "mock",
        "fallback_used": True,
        "fallback_reason": "AI microservice direct proxy fallback",
    }


@router.post("/catalog")
async def extract_catalog(payload: CatalogPayload):
    """
    Extracts structured listing from voice transcript.
    Enforces rule: Never invent missing specs; asks artisan for missing info.
    Generates 12-language translation matrix.
    """
    try:
        async with httpx.AsyncClient(timeout=20.0) as client:
            res = await client.post(f"{settings.AI_SERVICE_URL}/ai/catalog", json=payload.model_dump())
            res.raise_for_status()
            return res.json()
    except (httpx.HTTPError, ValueError) as exc:
        raise HTTPException(
            status_code=503,
            detail="AI catalog generation is unavailable. Your original description is preserved; enter or edit the product details and retry.",
        ) from exc


@router.get("/price/evaluation")
async def get_pricing_model_evaluation():
    """Expose real AI-service metrics only; never fabricate evaluation results."""
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            res = await client.get(f"{settings.AI_SERVICE_URL}/ai/price/evaluation")
            if res.status_code == 200:
                return res.json()
    except Exception:
        pass
    raise HTTPException(status_code=503, detail="Pricing evaluation service is unavailable")


@router.post("/price")
async def recommend_price(payload: PricePayload):
    """Reject the old unauthenticated estimator; pricing now belongs to a product draft."""
    raise HTTPException(
        status_code=410,
        detail="This pricing endpoint was retired. Use the authenticated product pricing routes.",
    )


@router.post("/price/validate-override")
async def validate_price_override(payload: PriceOverridePayload):
    """Retire the unauthenticated cost-floor validator with the old pricing API."""
    raise HTTPException(
        status_code=410,
        detail="This pricing endpoint was retired. Use authenticated product pricing routes.",
    )



@router.post("/enhance-image")
async def enhance_image(
    file: UploadFile = File(...),
    aspect_ratio: str = Form("1:1"),
):
    """Enhance a product image using the AI service or the local Pillow/OpenCV pipeline."""
    file_bytes = await file.read(10 * 1024 * 1024 + 1)
    if not file_bytes:
        raise HTTPException(status_code=400, detail="Uploaded image is empty")
    if len(file_bytes) > 10 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="Image must be 10 MB or smaller")
    try:
        files = {"file": (file.filename or "image.jpg", file_bytes, file.content_type or "image/jpeg")}
        data = {"aspect_ratio": aspect_ratio}
        async with httpx.AsyncClient(timeout=15.0) as client:
            res = await client.post(f"{settings.AI_SERVICE_URL}/ai/enhance-image", files=files, data=data)
            if res.status_code == 200:
                return res.json()
    except Exception:
        # Use the in-process image studio below when the separate AI service is
        # not deployed. The original bytes are never reported as enhanced data.
        pass
    try:
        from app.utils.image_studio import enhance_product_image
        output, width, height = enhance_product_image(file_bytes, aspect_ratio)
        data_uri = "data:image/jpeg;base64," + base64.b64encode(output).decode("ascii")
        return {
            "status": "success",
            "aspect_ratio": aspect_ratio,
            "width": width,
            "height": height,
            "enhanced_image_base64": data_uri,
        }
    except ValueError as exc:
        raise HTTPException(status_code=415, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=503, detail="Image processing is unavailable. The original upload is preserved; retry shortly.") from exc


@router.post("/generate-variations")
async def generate_variations(
    file: UploadFile = File(...),
    count: int = Form(10),
):
    """
    Generates exactly 10 distinct, selectable product photography variations
    preserving the genuine handcrafted craft's identity, color, and texture.
    """
    file_bytes = await file.read(10 * 1024 * 1024 + 1)
    if not file_bytes:
        raise HTTPException(status_code=400, detail="Uploaded file is empty")
    if len(file_bytes) > 10 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="Image must be 10 MB or smaller")

    try:
        from app.utils.image_studio import decode_product_image, process_and_generate_10_variations
        decode_product_image(file_bytes)
        result = await process_and_generate_10_variations(file_bytes, file.filename or "craft.jpg")
        if result.get("status") != "completed" or not result.get("variations"):
            raise RuntimeError("Image processor returned no completed variations")
        return result
    except ValueError as exc:
        raise HTTPException(status_code=415, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(
            status_code=503,
            detail="Image processing failed. No variations were created; your original upload is preserved.",
        ) from exc

