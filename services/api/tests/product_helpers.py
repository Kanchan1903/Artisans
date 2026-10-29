"""Database fixture helpers for tests that need already-published catalog items.

Publication behavior itself is exercised through the guarded endpoint in
test_product_publication.py. Domain tests seed legacy catalog state directly so
they can focus on orders, inquiries, search, and reporting.
"""
from datetime import datetime, timezone

from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.product import Product, ProductStatus


async def seed_published_product(
    client: AsyncClient,
    db_session: AsyncSession,
    headers: dict[str, str],
    payload: dict,
) -> dict:
    draft_payload = {**payload, "status": "draft"}
    created = await client.post("/api/v1/products", headers=headers, json=draft_payload)
    assert created.status_code == 201, created.text
    product_id = created.json()["id"]
    product = (
        await db_session.execute(select(Product).where(Product.id == product_id))
    ).scalar_one()
    product.status = ProductStatus.published
    product.published_at = datetime.now(timezone.utc)
    await db_session.commit()
    return created.json()
