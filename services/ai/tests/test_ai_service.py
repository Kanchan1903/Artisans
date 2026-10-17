"""Unit and integration tests for KalaSathi AI Microservice."""
import io
import pytest
from httpx import AsyncClient, ASGITransport
from PIL import Image

from app.main import app
from app.pricing.service import calculate_pricing
from app.speech.service import verify_language_support, SUPPORTED_LANGUAGES


@pytest.fixture
async def ai_client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        yield client


@pytest.mark.asyncio
async def test_ai_health(ai_client: AsyncClient):
    res = await ai_client.get("/health")
    assert res.status_code == 200
    data = res.json()
    assert data["status"] == "healthy"
    assert data["supported_languages_count"] == 12


@pytest.mark.asyncio
async def test_provider_capabilities_and_verification(ai_client: AsyncClient):
    # 1. Capabilities endpoint
    res = await ai_client.get("/ai/providers")
    assert res.status_code == 200
    data = res.json()
    assert len(data["supported_languages"]) == 12
    assert "bhashini" in data["providers"]
    assert "google" in data["providers"]
    assert "mock" in data["providers"]

    # 2. Language support verification function
    assert verify_language_support("bhashini", "asr", "mr") is True
    assert verify_language_support("bhashini", "tts", "ta") is True
    assert verify_language_support("mock", "asr", "as") is True
    # Google STT standard does not have Odia/Assamese
    assert verify_language_support("google", "asr", "or") is False
    assert verify_language_support("non_existent", "asr", "hi") is False


@pytest.mark.asyncio
async def test_speech_engine_transcription_and_tts(ai_client: AsyncClient):
    # Test all 12 languages transcribe successfully
    for lang in ["en", "hi", "mr", "bn", "ta", "te", "kn", "ml", "gu", "pa", "or", "as"]:
        trans_res = await ai_client.post("/ai/transcribe", data={"language": lang})
        assert trans_res.status_code == 200
        trans_data = trans_res.json()
        assert trans_data["language"] == lang
        assert len(trans_data["transcript"]) > 5

    # Test speech synthesis (Hindi and Marathi)
    for lang, text in [("hi", "उत्पाद सफलतापूर्वक प्रकाशित हो गया है।"), ("mr", "तुमचे उत्पादन प्रकाशित झाले आहे.")]:
        tts_res = await ai_client.post(
            "/ai/synthesize",
            json={"text": text, "language": lang},
        )
        assert tts_res.status_code == 200
        tts_data = tts_res.json()
        assert tts_data["format"] == "audio/wav"
        assert len(tts_data["audio_base64"]) > 50


@pytest.mark.asyncio
async def test_speech_unsupported_language_and_simulated_fallback(ai_client: AsyncClient):
    # 1. Completely unsupported language returns 400 with helpful error
    res_bad = await ai_client.post("/ai/transcribe", data={"language": "fr"})
    assert res_bad.status_code == 400
    assert "not supported" in res_bad.json()["detail"]

    # 2. Simulated failure triggers transparent fallback
    res_sim = await ai_client.post("/ai/transcribe", data={"language": "mr", "simulate_failure": "true"})
    assert res_sim.status_code == 200
    data = res_sim.json()
    assert data["provider_used"] == "mock"
    assert data["fallback_used"] is True
    assert "Simulated" in data["fallback_reason"]


@pytest.mark.asyncio
async def test_catalog_never_invents_missing_specs(ai_client: AsyncClient):
    # Voice note with NO material and NO technique
    vague_voice_note = "मी एक सुंदर वस्तू बनवली आहे. घरी ठेवण्यासाठी खूप छान आहे."
    res = await ai_client.post(
        "/ai/catalog",
        json={"transcript": vague_voice_note, "language": "mr"},
    )
    assert res.status_code == 200
    catalog = res.json()

    # Rule 8: NEVER invent missing product specifications
    assert catalog["material"] is None
    assert catalog["technique"] is None
    assert "material" in catalog["missing_fields"]
    assert "technique" in catalog["missing_fields"]

    # Localized clarification prompt in Marathi
    assert catalog["missing_info_prompt"] is not None
    assert "कृपया" in catalog["missing_info_prompt"] or "साहित्य" in catalog["missing_info_prompt"]

    # Check titles and short descriptions still present
    assert catalog["title_en"] is not None
    assert catalog["short_description_en"] is not None
    assert len(catalog["translations"]) == 12


@pytest.mark.asyncio
async def test_catalog_clarification_resolves_missing_specs(ai_client: AsyncClient):
    # Initial transcript missing specs
    vague_voice_note = "मी एक सुंदर वस्तू बनवली आहे."
    clarification = "साहित्य: नदीची माती आणि नैसर्गिक रंग. चाकावर हाताने घडवले आहे."

    res = await ai_client.post(
        "/ai/catalog",
        json={"transcript": vague_voice_note, "language": "mr", "clarification": clarification},
    )
    assert res.status_code == 200
    catalog = res.json()

    assert catalog["material"] is not None
    assert catalog["technique"] is not None
    assert len(catalog["missing_fields"]) == 0
    assert catalog["missing_info_prompt"] is None


@pytest.mark.asyncio
async def test_smart_pricing_assistant(ai_client: AsyncClient):
    res = await ai_client.post(
        "/ai/price",
        json={
            "craft_category": "Pottery",
            "material_cost": 80.0,
            "labor_hours": 4.5,
            "experience_years": 8,
            "complexity_score": 5,
            "language": "hi",
        },
    )
    assert res.status_code == 200
    data = res.json()
    assert data["cost_floor"] >= 460.0
    assert data["suggested_price"] > data["cost_floor"]
    assert data["premium_price"] > data["suggested_price"]


@pytest.mark.asyncio
async def test_image_studio_enhancement(ai_client: AsyncClient):
    img = Image.new("RGB", (300, 300), color=(180, 160, 140))
    for x in range(100, 200):
        for y in range(80, 220):
            img.putpixel((x, y), (200, 80, 40))

    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    buf.seek(0)

    files = {"file": ("test_pot.jpg", buf.getvalue(), "image/jpeg")}
    res = await ai_client.post("/ai/enhance-image", files=files, data={"aspect_ratio": "1:1"})
    assert res.status_code == 200
    data = res.json()
    assert data["status"] == "success"
    assert data["width"] == 1024
    assert data["height"] == 1024
    assert data["enhanced_image_base64"].startswith("data:image/jpeg;base64,")


@pytest.mark.asyncio
async def test_image_studio_variations_generation(ai_client: AsyncClient):
    """Test generating 10-15 studio variations for an artisan photograph."""
    img = Image.new("RGB", (300, 300), color=(180, 160, 140))
    for x in range(100, 200):
        for y in range(80, 220):
            img.putpixel((x, y), (200, 80, 40))

    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    files = {"file": ("test_pot.jpg", buf.getvalue(), "image/jpeg")}

    res = await ai_client.post("/ai/generate-variations", files=files, data={"count": "12"})
    assert res.status_code == 200
    data = res.json()
    assert data["status"] == "success"
    assert data["total_variations"] == 12
    variations = data["variations"]
    assert len(variations) == 12
    # Verify titles, styles, and data URIs
    for var in variations:
        assert var["id"].startswith("var_")
        assert len(var["title"]) > 0
        assert len(var["title_mr"]) > 0
        assert var["image_url"].startswith("data:image/jpeg;base64,")
    # Verify artisan can select 3-4 variations
    selected_3_or_4 = variations[:4]
    assert len(selected_3_or_4) == 4
    assert selected_3_or_4[0]["is_primary"] is True
