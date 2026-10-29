"""Authenticated upload of original artisan product photos to a draft."""
import io

import pytest
from httpx import AsyncClient
from PIL import Image


async def artisan_token(client: AsyncClient, phone: str = "+919555001234") -> str:
    sent = await client.post("/api/v1/auth/otp/send", json={"phone": phone, "role": "artisan"})
    verified = await client.post(
        "/api/v1/auth/otp/verify",
        json={"phone": phone, "code": sent.json()["mock_code"], "name": "Test Artisan"},
    )
    return verified.json()["access_token"]


def jpeg_bytes() -> bytes:
    image = Image.new("RGB", (8, 8), color="orange")
    buffer = io.BytesIO()
    image.save(buffer, format="JPEG")
    return buffer.getvalue()


@pytest.mark.asyncio
async def test_photo_upload_creates_owned_draft_and_is_idempotent(client: AsyncClient):
    token = await artisan_token(client)
    headers = {"Authorization": f"Bearer {token}"}
    data = {"upload_id": "photo_test_upload_001", "category_slug": "pottery"}
    file = {"file": ("craft.jpg", jpeg_bytes(), "image/jpeg")}

    response = await client.post("/api/v1/products/upload-image", headers=headers, data=data, files=file)
    assert response.status_code == 201, response.text
    uploaded = response.json()
    assert uploaded["status"] == "draft"
    assert uploaded["image_url"].startswith("https://storage.example.test/")

    again = await client.post("/api/v1/products/upload-image", headers=headers, data=data, files=file)
    assert again.status_code == 201, again.text
    assert again.json() == uploaded

    products = await client.get("/api/v1/products/artisan/me", headers=headers)
    assert products.status_code == 200
    assert len(products.json()) == 1
    assert products.json()[0]["id"] == uploaded["product_id"]
    assert products.json()[0]["status"] == "draft"
    assert len(products.json()[0]["images"]) == 1
    assert products.json()[0]["ai_generated"] is False

    replacement_data = {
        "upload_id": "photo_test_replacement_002",
        "product_id": str(uploaded["product_id"]),
    }
    replacement = await client.post(
        "/api/v1/products/upload-image",
        headers=headers,
        data=replacement_data,
        files=file,
    )
    assert replacement.status_code == 201, replacement.text
    assert replacement.json()["product_id"] == uploaded["product_id"]
    products = await client.get("/api/v1/products/artisan/me", headers=headers)
    assert len(products.json()[0]["images"]) == 1
    assert products.json()[0]["images"][0]["url"] == replacement.json()["image_url"]

    removed = await client.delete(
        f"/api/v1/products/upload-image/{replacement_data['upload_id']}", headers=headers
    )
    assert removed.status_code == 204
    repeated_remove = await client.delete(
        f"/api/v1/products/upload-image/{replacement_data['upload_id']}", headers=headers
    )
    assert repeated_remove.status_code == 204

    products = await client.get("/api/v1/products/artisan/me", headers=headers)
    assert products.json()[0]["images"] == []

    other_token = await artisan_token(client, "+919555001236")
    collision = await client.post(
        "/api/v1/products/upload-image",
        headers={"Authorization": f"Bearer {other_token}"},
        data=data,
        files=file,
    )
    assert collision.status_code == 201
    assert collision.json()["product_id"] != uploaded["product_id"]

    wrong_owner = await client.post(
        "/api/v1/products/upload-image",
        headers={"Authorization": f"Bearer {other_token}"},
        data={"upload_id": "other_owner_upload", "product_id": str(uploaded["product_id"])},
        files=file,
    )
    assert wrong_owner.status_code == 404


@pytest.mark.asyncio
async def test_photo_upload_requires_authentication(client: AsyncClient):
    response = await client.post(
        "/api/v1/products/upload-image",
        data={"upload_id": "unauth_upload"},
        files={"file": ("craft.jpg", jpeg_bytes(), "image/jpeg")},
    )
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_photo_upload_rejects_invalid_image(client: AsyncClient):
    token = await artisan_token(client, "+919555001235")
    response = await client.post(
        "/api/v1/products/upload-image",
        headers={"Authorization": f"Bearer {token}"},
        data={"upload_id": "invalid_upload"},
        files={"file": ("craft.jpg", b"not an image", "image/jpeg")},
    )
    assert response.status_code == 415
    assert "valid JPEG" in response.json()["detail"]


@pytest.mark.asyncio
async def test_photo_upload_rejects_oversized_file(client: AsyncClient):
    token = await artisan_token(client, "+919555001237")
    response = await client.post(
        "/api/v1/products/upload-image",
        headers={"Authorization": f"Bearer {token}"},
        data={"upload_id": "large_upload"},
        files={"file": ("craft.jpg", b"\xff\xd8\xff" + b"0" * (10 * 1024 * 1024), "image/jpeg")},
    )
    assert response.status_code == 413
