"""Tests for B2B wholesale inquiries and notifications."""
import pytest
from httpx import AsyncClient


async def get_user_token(client: AsyncClient, phone: str, role: str, name: str) -> str:
    res = await client.post("/api/v1/auth/otp/send", json={"phone": phone, "role": role})
    code = res.json()["mock_code"]
    verify = await client.post(
        "/api/v1/auth/otp/verify",
        json={"phone": phone, "code": code, "name": name},
    )
    return verify.json()["access_token"]


@pytest.mark.asyncio
async def test_b2b_inquiry_flow(client: AsyncClient, db_session):
    # 1. Artisan creates product
    artisan_token = await get_user_token(client, "+919444444444", "artisan", "Rameshwar Chitrakar")
    artisan_headers = {"Authorization": f"Bearer {artisan_token}"}

    from product_helpers import seed_published_product
    prod = await seed_published_product(
        client, db_session, artisan_headers, {
            "title_en": "Madhubani Tree of Life Painting",
            "price": 3500.0,
            "stock": 10,
            "status": "published",
        },
    )
    product_id = prod["id"]

    # 2. Buyer submits B2B inquiry
    buyer_token = await get_user_token(client, "+919555555555", "buyer", "FabIndia Procurement")
    buyer_headers = {"Authorization": f"Bearer {buyer_token}"}

    inq_res = await client.post(
        "/api/v1/inquiries",
        json={
            "product_id": product_id,
            "message": "We would like to order 50 pieces for our Diwali corporate gift boxes.",
            "quantity_needed": 50,
            "is_b2b": True,
        },
        headers=buyer_headers,
    )
    assert inq_res.status_code == 201
    inquiry_data = inq_res.json()
    assert inquiry_data["quantity_needed"] == 50
    assert inquiry_data["is_read"] is False
    inquiry_id = inquiry_data["id"]

    # 3. Artisan sees inquiry in their inbox
    inbox_res = await client.get("/api/v1/inquiries/artisan/me", headers=artisan_headers)
    assert inbox_res.status_code == 200
    inbox = inbox_res.json()
    assert any(i["id"] == inquiry_id for i in inbox)

    # 4. Artisan marks inquiry as read
    read_res = await client.patch(f"/api/v1/inquiries/{inquiry_id}/read", headers=artisan_headers)
    assert read_res.status_code == 200
    assert read_res.json()["is_read"] is True
