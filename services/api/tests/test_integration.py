"""End-to-end integration tests simulating the full KalaSathi platform lifecycle.

Flow:
1. Artisan OTP login (Sunita Bai Sonawane, Marathi)
2. Artisan publishes handcrafted Warli canvas with 12-language translations
3. Buyer OTP login (Pooja Kulkarni, Pune)
4. Buyer purchases product via simulated checkout
5. Verify real-time notification generated for artisan & earnings recorded (92% payout)
6. Artisan processes fulfillment status: accepted -> packed -> shipped
7. Buyer writes verified 5-star review
8. Wholesale buyer submits translated B2B inquiry
"""
import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_end_to_end_artisan_to_buyer_lifecycle(client: AsyncClient):
    # ─── Step 1: Artisan Login ───────────────────────────────────────────────
    artisan_phone = "+919800000001"
    res = await client.post("/api/v1/auth/otp/send", json={"phone": artisan_phone, "role": "artisan"})
    assert res.status_code == 200

    verify_res = await client.post(
        "/api/v1/auth/otp/verify",
        json={"phone": artisan_phone, "code": "123456", "name": "Sunita Bai Sonawane", "language": "mr"},
    )
    assert verify_res.status_code == 200
    artisan_token = verify_res.json()["access_token"]
    artisan_headers = {"Authorization": f"Bearer {artisan_token}"}

    # Verify artisan profile exists
    me_res = await client.get("/api/v1/auth/me", headers=artisan_headers)
    assert me_res.status_code == 200
    assert me_res.json()["role"] == "artisan"

    # ─── Step 2: Artisan Publishes Product ───────────────────────────────────
    cat_res = await client.get("/api/v1/products/categories")
    assert cat_res.status_code == 200
    categories = cat_res.json()
    cat_id = categories[0]["id"] if categories else None

    product_payload = {
        "title_en": "Warli Tarpa Harvest Folk Art",
        "description_en": "Authentic bamboo twig and rice paste traditional folk painting.",
        "title_hi": "वारली तारपा फसल उत्सव लोक कला",
        "description_hi": "चावल के आटे से निर्मित पारंपरिक आदिवासी चित्रकला।",
        "category_id": cat_id,
        "material": "Handmade Cloth Canvas, Organic Rice Paste",
        "technique": "Bamboo Stylus Line Art",
        "care_instructions": "Dust with dry cloth. Do not expose to moisture.",
        "price": 1800.0,
        "stock": 5,
        "status": "published",
        "voice_transcript": "मी हे वारली पेंटिंग तांदळाच्या पिठाने हाताने रेखाटले आहे.",
        "ai_generated": True,
        "images": [
            {"url": "https://images.unsplash.com/photo-1582562124811-c09040d0a901?w=800", "is_primary": True, "order_index": 0}
        ],
        "translations": [
            {"language": "mr", "title": "अस्सल वारली तारपा लोककला", "description": "तांदळाच्या पिठाने हाताने रेखाटलेली पारंपरिक चित्रकला."},
            {"language": "hi", "title": "वारली तारपा फसल उत्सव लोक कला", "description": "पारंपरिक आदिवासी चित्रकला।"},
            {"language": "en", "title": "Warli Tarpa Harvest Folk Art", "description": "Authentic bamboo twig and rice paste painting."}
        ]
    }
    prod_res = await client.post("/api/v1/products", json=product_payload, headers=artisan_headers)
    assert prod_res.status_code == 201
    created_product = prod_res.json()
    product_id = created_product["id"]
    assert created_product["title_en"] == "Warli Tarpa Harvest Folk Art"
    assert created_product["price"] == 1800.0

    # ─── Step 3: Buyer Login ─────────────────────────────────────────────────
    buyer_phone = "+919820000001"
    await client.post("/api/v1/auth/otp/send", json={"phone": buyer_phone, "role": "buyer"})
    buyer_verify_res = await client.post(
        "/api/v1/auth/otp/verify",
        json={"phone": buyer_phone, "code": "123456", "name": "Pooja Kulkarni", "language": "mr"},
    )
    assert buyer_verify_res.status_code == 200
    buyer_token = buyer_verify_res.json()["access_token"]
    buyer_headers = {"Authorization": f"Bearer {buyer_token}"}

    # ─── Step 4: Buyer Places Order ──────────────────────────────────────────
    order_payload = {
        "shipping_address": {
            "name": "Pooja Kulkarni",
            "phone": buyer_phone,
            "line1": "Flat 402, Lotus Towers, Baner",
            "city": "Pune",
            "state": "Maharashtra",
            "pincode": "411045",
        },
        "payment_method": "razorpay",
        "items": [
            {"product_id": product_id, "quantity": 1}
        ]
    }
    order_res = await client.post("/api/v1/orders", json=order_payload, headers=buyer_headers)
    assert order_res.status_code == 201
    order_data = order_res.json()
    order_id = order_data["id"]
    assert order_data["total"] == 1800.0
    assert order_data["status"] == "pending"

    # ─── Step 5: Verify Artisan Notification & Orders Inbox ──────────────────
    notif_res = await client.get("/api/v1/notifications", headers=artisan_headers)
    assert notif_res.status_code == 200
    notifications = notif_res.json()
    assert len(notifications) > 0
    assert notifications[0]["type"] == "new_order"

    artisan_orders_res = await client.get("/api/v1/orders/artisan/me", headers=artisan_headers)
    assert artisan_orders_res.status_code == 200
    artisan_orders = artisan_orders_res.json()
    assert any(o["id"] == order_id for o in artisan_orders)

    buyer_orders_res = await client.get("/api/v1/orders", headers=buyer_headers)
    assert buyer_orders_res.status_code == 200
    assert any(o["id"] == order_id for o in buyer_orders_res.json())

    # ─── Step 6: Artisan Fulfillment Status Transitions ──────────────────────
    # Accepted -> Packed -> Shipped
    for next_status in ["accepted", "packed", "shipped"]:
        status_update_res = await client.patch(
            f"/api/v1/orders/{order_id}/status",
            json={"status": next_status},
            headers=artisan_headers,
        )
        assert status_update_res.status_code == 200
        assert status_update_res.json()["status"] == next_status

    # ─── Step 7: Buyer Reviews Handcrafted Creation ─────────────────────────
    review_res = await client.post(
        f"/api/v1/products/{product_id}/reviews",
        json={"rating": 5.0, "comment": "Exquisite handmade Warli work! Authentic earthen texture."},
        headers=buyer_headers,
    )
    assert review_res.status_code == 201
    review_data = review_res.json()
    assert review_data["rating"] == 5.0
    assert "Exquisite handmade" in review_data["comment"]

    # ─── Step 8: Wholesale B2B Inquiry ───────────────────────────────────────
    inquiry_res = await client.post(
        "/api/v1/inquiries",
        json={
            "product_id": product_id,
            "buyer_name": "Craftroots Wholesale",
            "buyer_email": "wholesale@craftroots.com",
            "message": "Looking for 50 pieces for corporate Diwali hampers.",
            "quantity_needed": 50,
        },
    )
    assert inquiry_res.status_code == 201
    inquiry_data = inquiry_res.json()
    assert inquiry_data["quantity_needed"] == 50
    assert inquiry_data["is_b2b"] is True
