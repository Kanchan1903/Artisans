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

    # 1. Primary Live STT: ElevenLabs Scribe Speech-to-Text API
    eleven_key = getattr(settings, "ELEVENLABS_API_KEY", "") or "sk_87a1bb5e785cb1298d8852efbc26e6119d7a08fff472314e"
    if file and audio_bytes and eleven_key and not simulate_failure:
        try:
            async with httpx.AsyncClient(timeout=30.0) as stt_client:
                eleven_files = {"file": (file.filename or "recording.wav", audio_bytes, file.content_type or "audio/wav")}
                eleven_data = {"model_id": "scribe_v1"}
                if lang:
                    eleven_data["language_code"] = lang
                eleven_headers = {"xi-api-key": eleven_key}
                stt_res = await stt_client.post(
                    "https://api.elevenlabs.io/v1/speech-to-text",
                    headers=eleven_headers,
                    files=eleven_files,
                    data=eleven_data,
                )
                if stt_res.status_code == 200:
                    stt_json = stt_res.json()
                    transcript_text = stt_json.get("text", "").strip()
                    if transcript_text:
                        detected_lang = stt_json.get("language_code") or lang
                        return {
                            "transcript": transcript_text,
                            "language": detected_lang,
                            "provider_used": "elevenlabs_scribe",
                            "fallback_used": False,
                            "confidence": 0.95,
                        }
        except Exception as exc:
            logger.warning("ElevenLabs STT live conversion warning: %s", exc)

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


class ComposeBackgroundPayload(BaseModel):
    cutout_base64: str = Field(..., min_length=10)
    background_type: str = Field("color")  # 'color', 'wood', 'studio', 'festive'
    bg_color_hex: str = Field("#FFFFFF")
    has_shadow: bool = Field(True)


@router.post("/remove-background")
async def remove_background_endpoint(
    file: UploadFile = File(...),
):
    """
    Step 1 of WhatsApp-like Studio: Extract the clean transparent foreground craft cutout (PNG).
    Strictly preserves the original product pixels, geometry, texture, and colors.
    """
    file_bytes = await file.read(10 * 1024 * 1024 + 1)
    if not file_bytes:
        raise HTTPException(status_code=400, detail="Uploaded file is empty")
    if len(file_bytes) > 10 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="Image must be 10 MB or smaller")

    try:
        from app.utils.image_studio import decode_product_image, remove_background
        import io
        raw_pil, _, _ = decode_product_image(file_bytes)
        cutout = remove_background(raw_pil)
        buf = io.BytesIO()
        cutout.save(buf, format="PNG")
        cutout_bytes = buf.getvalue()
        b64 = base64.b64encode(cutout_bytes).decode("ascii")
        return {
            "status": "success",
            "width": cutout.width,
            "height": cutout.height,
            "cutout_base64": f"data:image/png;base64,{b64}",
        }
    except ValueError as exc:
        raise HTTPException(status_code=415, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(
            status_code=503,
            detail=f"Background removal error: {str(exc)}",
        ) from exc


@router.post("/compose-background")
async def compose_background_endpoint(
    payload: ComposeBackgroundPayload,
):
    """
    Step 2 of WhatsApp-like Studio: Real-time background composition behind the segmented craft cutout.
    Composites the clean product cutout onto solid colors, textures, or custom hex color.
    """
    try:
        import io
        from PIL import Image
        from app.utils.image_studio import create_variation_composition, generate_procedural_background

        # Decode base64 cutout
        data_str = payload.cutout_base64
        if "," in data_str:
            data_str = data_str.split(",", 1)[1]
        cutout_bytes = base64.b64decode(data_str)
        cutout_img = Image.open(io.BytesIO(cutout_bytes)).convert("RGBA")

        # Parse hex color
        hex_clean = payload.bg_color_hex.lstrip("#")
        if len(hex_clean) == 6:
            r = int(hex_clean[0:2], 16)
            g = int(hex_clean[2:4], 16)
            b = int(hex_clean[4:6], 16)
        else:
            r, g, b = (255, 255, 255)

        bg_canvas = None
        if payload.background_type == "wood":
            bg_canvas = generate_procedural_background("wooden_texture")
        elif payload.background_type == "studio":
            bg_canvas = generate_procedural_background("studio_background")
        elif payload.background_type == "festive":
            bg_canvas = generate_procedural_background("festive_background")

        comp = create_variation_composition(
            cutout_img,
            target_size=(1024, 1024),
            bg_color_top=(r, g, b),
            has_shadow=payload.has_shadow,
            bg_canvas=bg_canvas,
        )

        out_buf = io.BytesIO()
        comp.save(out_buf, format="JPEG", quality=90, optimize=True)
        comp_bytes = out_buf.getvalue()
        b64 = base64.b64encode(comp_bytes).decode("ascii")

        return {
            "status": "success",
            "composed_image_base64": f"data:image/jpeg;base64,{b64}",
        }
    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Background composition error: {str(exc)}",
        ) from exc


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



class VoiceDescriptionWorkflowPayload(BaseModel):
    transcript: str = Field(..., min_length=1)
    preferred_language: str | None = Field(default=None)
    clarification: str | None = Field(default=None)


@router.post("/voice-description-agent")
async def process_voice_description_workflow(payload: VoiceDescriptionWorkflowPayload):
    """
    Multilingual AI Product Description Agent Workflow:
    Coordinates Voice Agent, Product Information Agent, Research Agent,
    Description Agent, Fact-Checking Agent, and Coordinator Agent.
    Strictly preserves artisan voice facts without generative hallucinations.
    """
    from app.utils.voice_description_agents import VoiceDescriptionCoordinator
    coordinator = VoiceDescriptionCoordinator()
    result = await coordinator.execute_workflow(
        transcript=payload.transcript,
        preferred_language=payload.preferred_language,
        clarification=payload.clarification,
    )
    return result


class DynamicPricingWorkflowPayload(BaseModel):
    title: str = Field(..., min_length=1)
    category_slug: str = Field(default="pottery")
    material: str | None = Field(default=None)
    description: str | None = Field(default=None)
    material_cost: float | None = Field(default=None)
    labor_hours: float | None = Field(default=None)
    hourly_rate: float | None = Field(default=None)
    packaging_cost: float | None = Field(default=None)
    shipping_cost: float | None = Field(default=None)
    desired_profit: float | None = Field(default=None)
    voice_feedback: str | None = Field(default=None)


@router.post("/dynamic-pricing-agent")
async def process_dynamic_pricing_workflow(payload: DynamicPricingWorkflowPayload):
    """
    Dynamic Pricing AI Agent Workflow:
    Coordinates Market Research Agent, Cost Analysis Agent, Pricing Recommendation Agent,
    Voice Feedback Agent, Pricing Validation Agent, and Coordinator Agent.
    Fetches real internet marketplace benchmarks & recalculates based on voice feedback.
    """
    from app.utils.dynamic_pricing_agents import DynamicPricingCoordinator
    coordinator = DynamicPricingCoordinator()
    costs = {
        "material_cost": payload.material_cost,
        "labor_hours": payload.labor_hours,
        "hourly_rate": payload.hourly_rate,
        "packaging_cost": payload.packaging_cost,
        "shipping_cost": payload.shipping_cost,
        "desired_profit": payload.desired_profit,
    }
    result = await coordinator.generate_price_recommendation(
        title=payload.title,
        category_slug=payload.category_slug,
        material=payload.material,
        description=payload.description,
        costs=costs,
        voice_feedback=payload.voice_feedback,
    )
    return result
