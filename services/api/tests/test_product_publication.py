"""Final review, ownership, and publication gate integration tests."""
import pytest
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.image_job import ImageProcessingJob
from app.models.product import Product, ProductStatus


async def artisan_token(client: AsyncClient, phone: str) -> str:
    sent = await client.post(
        "/api/v1/auth/otp/send", json={"phone": phone, "role": "artisan"}
    )
    verified = await client.post(
        "/api/v1/auth/otp/verify",
        json={
            "phone": phone,
            "code": sent.json()["mock_code"],
            "name": "Review Artisan",
            "language": "en",
        },
    )
    return verified.json()["access_token"]


async def make_draft(client: AsyncClient, token: str) -> dict:
    response = await client.post(
        "/api/v1/products",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "category_slug": "pottery",
            "title_en": "Handmade Clay Serving Bowl",
            "description_en": "A hand thrown terracotta bowl finished by the artisan.",
            "material": "terracotta clay",
            "technique": "wheel throwing",
            "price": 0,
            "stock": 4,
            "status": "draft",
        },
    )
    assert response.status_code == 201, response.text
    return response.json()


async def add_image_job(
    db: AsyncSession,
    product: dict,
    *,
    requires_review: bool = False,
    status: str = "completed",
    count: int = 3,
    duplicate_urls: bool = False,
) -> str:
    job_id = f"publication-job-{product['id']}"
    variants = [
        {
            "id": f"variant-{index}",
            "variant_id": f"variant-{index}",
            "image_url": (
                "https://storage.example.test/shared.jpg"
                if duplicate_urls
                else f"https://storage.example.test/variant-{index}.jpg"
            ),
            "saved": True,
            "status": "ready_for_review",
        }
        for index in range(count)
    ]
    db.add(
        ImageProcessingJob(
            id=job_id,
            artisan_id=product["artisan_id"],
            product_id=product["id"],
            status=status,
            segmentation_status="completed",
            original_photo_url="https://storage.example.test/original.jpg",
            original_storage_key="original.jpg",
            variants=variants,
            selected_variant_ids=[],
            requires_review=requires_review,
            quality_warnings=[],
            errors=[],
        )
    )
    await db.commit()
    return job_id


async def select_custom_price(
    client: AsyncClient, token: str, product_id: int, price: float = 450
) -> int:
    headers = {"Authorization": f"Bearer {token}"}
    recommendation = await client.post(
        f"/api/v1/products/{product_id}/pricing/recommendations",
        headers=headers,
        json={"idempotency_key": f"publication-price-{product_id}"},
    )
    assert recommendation.status_code == 200, recommendation.text
    selected = await client.put(
        f"/api/v1/products/{product_id}/pricing/selection",
        headers=headers,
        json={
            "revision_id": recommendation.json()["revision_id"],
            "price": price,
            "selection_source": "custom",
        },
    )
    assert selected.status_code == 200, selected.text
    return recommendation.json()["revision_id"]


def publish_payload(product: dict, job_id: str, price: float = 450) -> dict:
    return {
        "price": price,
        "price_confirmed": True,
        "description_confirmed": True,
        "image_job_id": job_id,
        "selected_variant_ids": ["variant-0", "variant-1", "variant-2"],
        "idempotency_key": f"publish-{product['id']}-{job_id}",
    }


@pytest.mark.asyncio
async def test_publish_draft_saves_exactly_three_images_and_is_idempotent(
    client: AsyncClient, db_session: AsyncSession
):
    token = await artisan_token(client, "+919111111101")
    headers = {"Authorization": f"Bearer {token}"}
    draft = await make_draft(client, token)
    job_id = await add_image_job(db_session, draft)
    await select_custom_price(client, token, draft["id"])

    published = await client.post(
        f"/api/v1/products/{draft['id']}/publish",
        headers=headers,
        json=publish_payload(draft, job_id),
    )
    assert published.status_code == 200, published.text
    data = published.json()
    assert data["status"] == "published"
    assert data["price"] == 450
    assert len(data["images"]) == 3
    assert sum(image["is_primary"] for image in data["images"]) == 1

    repeated = await client.post(
        f"/api/v1/products/{draft['id']}/publish",
        headers=headers,
        json=publish_payload(draft, job_id),
    )
    assert repeated.status_code == 200, repeated.text
    assert repeated.json()["id"] == data["id"]

    catalog = await client.get("/api/v1/products")
    matches = [item for item in catalog.json()["items"] if item["id"] == draft["id"]]
    assert len(matches) == 1


@pytest.mark.asyncio
async def test_drafts_are_hidden_and_direct_publication_is_rejected(client: AsyncClient):
    token = await artisan_token(client, "+919111111102")
    draft = await make_draft(client, token)
    public_detail = await client.get(f"/api/v1/products/{draft['id']}")
    assert public_detail.status_code == 404

    direct = await client.post(
        "/api/v1/products",
        headers={"Authorization": f"Bearer {token}"},
        json={"title_en": "Bypass listing", "price": 200, "status": "published"},
    )
    assert direct.status_code == 409


@pytest.mark.asyncio
async def test_review_rejects_unconfirmed_price_description_and_pending_images(
    client: AsyncClient, db_session: AsyncSession
):
    token = await artisan_token(client, "+919111111103")
    headers = {"Authorization": f"Bearer {token}"}
    draft = await make_draft(client, token)
    job_id = await add_image_job(db_session, draft, requires_review=True, status="awaiting_review")
    await select_custom_price(client, token, draft["id"])
    body = publish_payload(draft, job_id)

    unconfirmed = await client.post(
        f"/api/v1/products/{draft['id']}/publish",
        headers=headers,
        json={**body, "price_confirmed": False},
    )
    assert unconfirmed.status_code == 422

    pending = await client.post(
        f"/api/v1/products/{draft['id']}/publish", headers=headers, json=body
    )
    assert pending.status_code == 409


@pytest.mark.asyncio
@pytest.mark.parametrize("count", [2, 4])
async def test_review_rejects_wrong_image_count(
    client: AsyncClient, db_session: AsyncSession, count: int
):
    token = await artisan_token(client, f"+91911111110{count}")
    headers = {"Authorization": f"Bearer {token}"}
    draft = await make_draft(client, token)
    job_id = await add_image_job(db_session, draft, count=count)
    await select_custom_price(client, token, draft["id"])
    body = publish_payload(draft, job_id)
    body["selected_variant_ids"] = [f"variant-{i}" for i in range(count)]

    response = await client.post(
        f"/api/v1/products/{draft['id']}/publish", headers=headers, json=body
    )
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_review_rejects_duplicate_ids_duplicate_urls_and_failed_processing(
    client: AsyncClient, db_session: AsyncSession
):
    token = await artisan_token(client, "+919111111107")
    headers = {"Authorization": f"Bearer {token}"}

    duplicate_id_draft = await make_draft(client, token)
    duplicate_id_job = await add_image_job(db_session, duplicate_id_draft)
    await select_custom_price(client, token, duplicate_id_draft["id"])
    duplicate_ids = publish_payload(duplicate_id_draft, duplicate_id_job)
    duplicate_ids["selected_variant_ids"] = ["variant-0", "variant-0", "variant-2"]
    response = await client.post(
        f"/api/v1/products/{duplicate_id_draft['id']}/publish",
        headers=headers,
        json=duplicate_ids,
    )
    assert response.status_code == 422

    duplicate_url_draft = await make_draft(client, token)
    duplicate_url_job = await add_image_job(
        db_session, duplicate_url_draft, duplicate_urls=True
    )
    await select_custom_price(client, token, duplicate_url_draft["id"])
    response = await client.post(
        f"/api/v1/products/{duplicate_url_draft['id']}/publish",
        headers=headers,
        json=publish_payload(duplicate_url_draft, duplicate_url_job),
    )
    assert response.status_code == 422

    failed_draft = await make_draft(client, token)
    failed_job = await add_image_job(
        db_session, failed_draft, status="failed", requires_review=True
    )
    await select_custom_price(client, token, failed_draft["id"])
    response = await client.post(
        f"/api/v1/products/{failed_draft['id']}/publish",
        headers=headers,
        json=publish_payload(failed_draft, failed_job),
    )
    assert response.status_code == 409


@pytest.mark.asyncio
async def test_review_rejects_missing_description_and_invalid_price(
    client: AsyncClient, db_session: AsyncSession
):
    token = await artisan_token(client, "+919111111108")
    headers = {"Authorization": f"Bearer {token}"}
    draft = await make_draft(client, token)
    job_id = await add_image_job(db_session, draft)
    await select_custom_price(client, token, draft["id"])

    saved_empty_description = await client.put(
        f"/api/v1/products/{draft['id']}",
        headers=headers,
        json={"description_en": ""},
    )
    assert saved_empty_description.status_code == 200
    response = await client.post(
        f"/api/v1/products/{draft['id']}/publish",
        headers=headers,
        json=publish_payload(draft, job_id),
    )
    assert response.status_code == 422

    invalid_price = publish_payload(draft, job_id)
    invalid_price["price"] = 0
    response = await client.post(
        f"/api/v1/products/{draft['id']}/publish",
        headers=headers,
        json=invalid_price,
    )
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_other_artisan_cannot_publish_a_draft(client: AsyncClient, db_session: AsyncSession):
    owner_token = await artisan_token(client, "+919111111105")
    other_token = await artisan_token(client, "+919111111106")
    draft = await make_draft(client, owner_token)
    job_id = await add_image_job(db_session, draft)
    await select_custom_price(client, owner_token, draft["id"])

    response = await client.post(
        f"/api/v1/products/{draft['id']}/publish",
        headers={"Authorization": f"Bearer {other_token}"},
        json=publish_payload(draft, job_id),
    )
    assert response.status_code == 404
    stored = (
        await db_session.execute(select(Product).where(Product.id == draft["id"]))
    ).scalar_one()
    assert stored.status == ProductStatus.draft
