"""Unit and integration tests for Backend API AI endpoints & draft saving."""
import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_ai_provider_capabilities(client: AsyncClient):
    res = await client.get("/api/v1/ai/providers")
    assert res.status_code == 200
    data = res.json()
    assert "supported_languages" in data
    assert len(data["supported_languages"]) == 12
    assert "providers" in data


@pytest.mark.asyncio
async def test_ai_transcribe_and_unsupported_language(client: AsyncClient):
    # 1. Supported language (Marathi)
    res = await client.post("/api/v1/ai/transcribe", data={"language": "mr"})
    assert res.status_code == 200
    data = res.json()
    assert data["language"] == "mr"
    assert len(data["transcript"]) > 5

    # 2. Unsupported language gives 400
    res_bad = await client.post("/api/v1/ai/transcribe", data={"language": "spanish"})
    assert res_bad.status_code == 400
    assert "not supported" in res_bad.json()["detail"]


@pytest.mark.asyncio
async def test_ai_catalog_missing_specifications(client: AsyncClient):
    # Voice note with missing specifications
    res = await client.post(
        "/api/v1/ai/catalog",
        json={"transcript": "मी एक सुंदर वस्तू बनवली आहे.", "language": "mr"},
    )
    assert res.status_code == 200
    data = res.json()
    assert data["material"] is None
    assert data["technique"] is None
    assert "material" in data["missing_fields"]
    assert "technique" in data["missing_fields"]
    assert data["missing_info_prompt"] is not None
    assert len(data["translations"]) == 12


@pytest.mark.asyncio
async def test_ai_synthesize_speech(client: AsyncClient):
    res = await client.post(
        "/api/v1/ai/synthesize",
        json={"text": "उत्पाद विवरण", "language": "hi"},
    )
    assert res.status_code == 200
    data = res.json()
    assert data["format"] == "audio/wav"
    assert len(data["audio_base64"]) > 50


@pytest.mark.asyncio
async def test_save_product_draft_with_translations_and_images(client: AsyncClient):
    # 1. Login as artisan
    artisan_phone = "+919800000001"
    await client.post("/api/v1/auth/otp/send", json={"phone": artisan_phone, "role": "artisan"})
    verify_res = await client.post(
        "/api/v1/auth/otp/verify",
        json={"phone": artisan_phone, "code": "123456", "name": "Sunita Bai", "language": "mr"},
    )
    assert verify_res.status_code == 200
    token = verify_res.json()["access_token"]
    artisan_headers = {"Authorization": f"Bearer {token}"}

    # 2. Save in-progress product as a draft with voice transcript and 12-lang translations
    draft_payload = {
        "title_en": "Draft Terracotta Pitcher",
        "description_en": "Draft description in progress",
        "title_hi": "कच्चा टेराकोटा घड़ा",
        "description_hi": "प्रगति में विवरण",
        "material": "Riverbed Clay",
        "technique": "Wheel Throwing",
        "price": 450.0,
        "stock": 1,
        "status": "draft",
        "voice_transcript": "हा मातीचा सुंदर पाण्याचा घडा आहे.",
        "ai_generated": True,
        "images": [
            {"url": "https://images.unsplash.com/photo-1578749556568-bc2c40e68b61?w=600", "is_primary": True}
        ],
        "translations": [
            {"language": "mr", "title": "हातमातीचे पाण्याचे भांडे", "description": "नैसर्गिक मातीचे भांडे."},
            {"language": "hi", "title": "टेराकोटा जलपात्र", "description": "प्राकृतिक मिट्टी से बना पात्र।"},
        ],
    }

    res = await client.post("/api/v1/products", json=draft_payload, headers=artisan_headers)
    assert res.status_code == 201
    product = res.json()
    assert product["status"] == "draft"
    assert product["title_en"] == "Draft Terracotta Pitcher"
    assert product["voice_transcript"] == "हा मातीचा सुंदर पाण्याचा घडा आहे."
    assert len(product["images"]) == 1
    assert len(product["translations"]) == 2
