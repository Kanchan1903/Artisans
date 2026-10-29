"""Tests for product catalog, artisan publishing, and stock updates."""
import pytest
from httpx import AsyncClient


async def get_artisan_token(client: AsyncClient, phone: str = "+919111111111") -> str:
    res = await client.post("/api/v1/auth/otp/send", json={"phone": phone, "role": "artisan"})
    code = res.json()["mock_code"]
    verify = await client.post(
        "/api/v1/auth/otp/verify",
        json={"phone": phone, "code": code, "name": "Basavaraju", "language": "kn"},
    )
    return verify.json()["access_token"]


@pytest.mark.asyncio
async def test_artisan_create_and_browse_product(client: AsyncClient, db_session):
    token = await get_artisan_token(client)
    headers = {"Authorization": f"Bearer {token}"}

    # 1. Fetch categories
    cat_res = await client.get("/api/v1/products/categories")
    assert cat_res.status_code == 200
    categories = cat_res.json()
    assert len(categories) > 0
    cat_id = categories[0]["id"]

    # 2. Artisan creates and publishes product
    product_payload = {
        "category_id": cat_id,
        "title_en": "Handcrafted Clay Water Jug (Surahi)",
        "description_en": "Traditional terracotta water jug naturally cooling drinking water.",
        "title_hi": "हस्तनिर्मित मिट्टी की सुराही",
        "description_hi": "पारंपरिक टेराकोटा पानी का जग।",
        "material": "Riverbed Clay",
        "technique": "Wheel Throwing",
        "care_instructions": "Rinse with clean water before use.",
        "seo_keywords": ["terracotta", "clay", "pottery", "handcrafted"],
        "price": 450.0,
        "stock": 10,
        "status": "published",
        "ai_generated": True,
        "images": [{"url": "https://example.com/jug.jpg", "is_primary": True, "order_index": 0}],
        "translations": [
            {"language": "hi", "title": "हस्तनिर्मित मिट्टी की सुराही", "description": "पारंपरिक टेराकोटा जग"},
            {"language": "mr", "title": "हातमातीची सुरई", "description": "पारंपारिक मातीचे भांडे"},
        ],
    }

    from product_helpers import seed_published_product
    prod = await seed_published_product(client, db_session, headers, product_payload)
    assert prod["title_en"] == "Handcrafted Clay Water Jug (Surahi)"
    assert prod["price"] == 450.0
    assert prod["stock"] == 10
    product_id = prod["id"]

    direct_publish = await client.post(
        "/api/v1/products", json=product_payload, headers=headers
    )
    assert direct_publish.status_code == 409

    # 3. Public buyers can browse products
    browse_res = await client.get("/api/v1/products")
    assert browse_res.status_code == 200
    catalog = browse_res.json()
    assert catalog["total"] >= 1
    assert any(p["id"] == product_id for p in catalog["items"])

    # 4. Detail view
    detail_res = await client.get(f"/api/v1/products/{product_id}")
    assert detail_res.status_code == 200
    assert len(detail_res.json()["translations"]) == 2

    # 5. Stock update by artisan (voice/tap)
    stock_res = await client.patch(
        f"/api/v1/products/{product_id}/stock", json={"stock": 15}, headers=headers
    )
    assert stock_res.status_code == 200
    assert stock_res.json()["stock"] == 15
