"""Tests for evidence-based product pricing and artisan approval history."""
import pytest
from httpx import AsyncClient
from sqlalchemy import select

from app.models.product import Product


async def artisan_token(client: AsyncClient, phone: str = "+919111111111") -> str:
    sent = await client.post("/api/v1/auth/otp/send", json={"phone": phone, "role": "artisan"})
    verified = await client.post(
        "/api/v1/auth/otp/verify",
        json={
            "phone": phone,
            "code": sent.json()["mock_code"],
            "name": "Pricing Artisan",
            "language": "en",
        },
    )
    return verified.json()["access_token"]


async def add_product(
    client: AsyncClient,
    headers: dict[str, str],
    *,
    title: str,
    price: float,
    status: str,
) -> dict:
    response = await client.post(
        "/api/v1/products",
        headers=headers,
        json={
            "category_slug": "pottery",
            "title_en": title,
            "description_en": "Hand thrown clay pottery vessel",
            "material": "terracotta clay",
            "technique": "wheel throwing",
            "price": price,
            "stock": 4,
            "status": status,
            "images": [],
        },
    )
    assert response.status_code == 201, response.text
    return response.json()


@pytest.mark.asyncio
async def test_legacy_unauthenticated_estimator_is_retired(client: AsyncClient):
    response = await client.post(
        "/api/v1/ai/price",
        json={"craft_category": "pottery", "material_cost": 200, "labor_hours": 4},
    )
    assert response.status_code == 410


@pytest.mark.asyncio
async def test_recommendation_uses_published_same_category_prices_and_saves_history(client: AsyncClient):
    token = await artisan_token(client)
    headers = {"Authorization": f"Bearer {token}"}
    for title, price in (("Terracotta Jar", 100), ("Clay Storage Pot", 200), ("Handmade Clay Pitcher", 300)):
        await add_product(client, headers, title=title, price=price, status="published")
    draft = await add_product(client, headers, title="Clay Serving Bowl", price=0, status="draft")

    response = await client.post(
        f"/api/v1/products/{draft['id']}/pricing/recommendations",
        headers=headers,
        json={"idempotency_key": "recommendation-first-001"},
    )
    assert response.status_code == 200, response.text
    recommendation = response.json()
    assert recommendation["suggested_price"] == 200
    assert recommendation["price_range_min"] == 100
    assert recommendation["price_range_max"] == 300
    assert len(recommendation["comparable_products"]) == 3
    assert recommendation["confidence"] == "medium"
    assert recommendation["requires_review"] is False

    history = await client.get(f"/api/v1/products/{draft['id']}/pricing/history", headers=headers)
    assert history.status_code == 200
    assert [row["revision_id"] for row in history.json()] == [recommendation["revision_id"]]


@pytest.mark.asyncio
async def test_challenge_rechecks_live_catalog_and_selection_stays_draft(
    client: AsyncClient, db_session
):
    token = await artisan_token(client)
    headers = {"Authorization": f"Bearer {token}"}
    await add_product(client, headers, title="Terracotta Cup", price=100, status="published")
    await add_product(client, headers, title="Clay Water Pot", price=200, status="published")
    draft = await add_product(client, headers, title="Clay Craft Bowl", price=0, status="draft")
    base_url = f"/api/v1/products/{draft['id']}/pricing"

    first = await client.post(
        f"{base_url}/recommendations", headers=headers,
        json={"idempotency_key": "recommendation-challenge-001"},
    )
    assert first.status_code == 200, first.text
    await add_product(client, headers, title="Clay Decor Plate", price=300, status="published")

    challenged = await client.post(
        f"{base_url}/challenges", headers=headers,
        json={
            "previous_revision_id": first.json()["revision_id"],
            "reason": "size_or_detail",
            "context": "This bowl has extra hand-painted detail.",
            "idempotency_key": "challenge-recheck-001",
        },
    )
    assert challenged.status_code == 200, challenged.text
    revised = challenged.json()
    assert revised["previous_revision_id"] == first.json()["revision_id"]
    assert revised["version"] == 2
    assert revised["suggested_price"] == 200
    assert len(revised["comparable_products"]) == 3

    blocked = await client.post(f"/api/v1/products/{draft['id']}/publish", headers=headers)
    assert blocked.status_code == 422

    selected = await client.put(
        f"{base_url}/selection", headers=headers,
        json={
            "revision_id": revised["revision_id"],
            "price": 200,
            "selection_source": "suggested",
        },
    )
    assert selected.status_code == 200, selected.text
    assert selected.json()["selected_price"] == 200
    saved_product = (
        await db_session.execute(select(Product).where(Product.id == draft["id"]))
    ).scalar_one()
    await db_session.refresh(saved_product)
    assert saved_product.price == 200
    assert saved_product.status.value == "draft"

@pytest.mark.asyncio
async def test_pricing_requires_authentication(client: AsyncClient):
    response = await client.post(
        "/api/v1/products/1/pricing/recommendations",
        json={"idempotency_key": "unauthorized-rec-01"},
    )
    assert response.status_code == 401
