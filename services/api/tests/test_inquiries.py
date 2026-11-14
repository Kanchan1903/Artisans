"""Tests for B2B wholesale inquiries, scheduling, negotiation, and order confirmation."""
from datetime import datetime, timezone
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

    # 2. Buyer submits B2B inquiry with phone and email
    buyer_token = await get_user_token(client, "+919555555555", "buyer", "FabIndia Procurement")
    buyer_headers = {"Authorization": f"Bearer {buyer_token}"}

    inq_res = await client.post(
        "/api/v1/inquiries",
        json={
            "product_id": product_id,
            "buyer_name": "FabIndia Procurement",
            "buyer_phone": "+91 98765 43210",
            "buyer_email": "procure@fabindia.com",
            "message": "We would like to order 5 pieces for our Diwali corporate gift boxes.",
            "quantity_needed": 5,
            "is_b2b": True,
        },
        headers=buyer_headers,
    )
    assert inq_res.status_code == 201
    inquiry_data = inq_res.json()
    assert inquiry_data["buyer_phone"] == "+91 98765 43210"
    assert inquiry_data["buyer_email"] == "procure@fabindia.com"
    assert inquiry_data["quantity_needed"] == 5
    assert inquiry_data["is_read"] is False
    assert inquiry_data["status"] == "new"
    inquiry_id = inquiry_data["id"]

    # 3. Duplicate prevention: submitting exact same inquiry within minutes returns the existing inquiry
    dup_res = await client.post(
        "/api/v1/inquiries",
        json={
            "product_id": product_id,
            "buyer_name": "FabIndia Procurement",
            "buyer_phone": "+91 98765 43210",
            "buyer_email": "procure@fabindia.com",
            "message": "We would like to order 5 pieces for our Diwali corporate gift boxes.",
            "quantity_needed": 5,
            "is_b2b": True,
        },
        headers=buyer_headers,
    )
    assert dup_res.status_code == 201
    assert dup_res.json()["id"] == inquiry_id

    # 4. Artisan views inbox
    inbox_res = await client.get("/api/v1/inquiries/artisan/me", headers=artisan_headers)
    assert inbox_res.status_code == 200
    inbox = inbox_res.json()
    matched = next((i for i in inbox if i["id"] == inquiry_id), None)
    assert matched is not None
    assert matched["buyer_phone"] == "+91 98765 43210"

    # 5. Artisan schedules contact with date/time
    sched_res = await client.patch(
        f"/api/v1/inquiries/{inquiry_id}/status",
        json={
            "status": "contact_scheduled",
            "scheduled_contact_at": datetime.now(timezone.utc).isoformat(),
            "contact_notes": "Artisan will WhatsApp buyer at 4 PM tomorrow",
        },
        headers=artisan_headers,
    )
    assert sched_res.status_code == 200
    assert sched_res.json()["status"] == "contact_scheduled"
    assert sched_res.json()["scheduled_contact_at"] is not None

    # 6. Artisan updates status to negotiation
    neg_res = await client.patch(
        f"/api/v1/inquiries/{inquiry_id}/status",
        json={
            "status": "negotiation",
            "contact_notes": "Negotiating bulk discount on 5 pieces",
            "artisan_response": "We can offer 5 units at Rs 3200 each.",
        },
        headers=artisan_headers,
    )
    assert neg_res.status_code == 200
    assert neg_res.json()["status"] == "negotiation"

    # 7. Artisan confirms agreed order with price, quantity, and delivery details
    confirm_res = await client.post(
        f"/api/v1/inquiries/{inquiry_id}/confirm-order",
        json={
            "agreed_price": 16000.0,
            "agreed_quantity": 5,
            "delivery_details": "Dispatch by Nov 20 via Speed Post to FabIndia Mumbai HQ",
            "contact_notes": "Advance payment received on UPI",
        },
        headers=artisan_headers,
    )
    assert confirm_res.status_code == 200
    confirmed_data = confirm_res.json()
    assert confirmed_data["status"] == "order_confirmed"
    assert confirmed_data["agreed_price"] == 16000.0
    assert confirmed_data["agreed_quantity"] == 5
    assert confirmed_data["confirmed_at"] is not None

    # 8. Artisan completes the order
    complete_res = await client.patch(
        f"/api/v1/inquiries/{inquiry_id}/status",
        json={
            "status": "completed",
            "contact_notes": "Parcel delivered and acknowledged by buyer.",
        },
        headers=artisan_headers,
    )
    assert complete_res.status_code == 200
    assert complete_res.json()["status"] == "completed"

    # 9. Out of stock / unavailable product inquiry rejection
    prod_out_of_stock = await seed_published_product(
        client, db_session, artisan_headers, {
            "title_en": "Sold Out Warli Art",
            "price": 1200.0,
            "stock": 0,
            "status": "published",
        },
    )
    rejected_res = await client.post(
        "/api/v1/inquiries",
        json={
            "product_id": prod_out_of_stock["id"],
            "buyer_name": "Interested Buyer",
            "message": "Can I buy this sold out piece?",
        },
        headers=buyer_headers,
    )
    assert rejected_res.status_code == 400
    assert "out of stock / unavailable" in rejected_res.json()["detail"]
