"""Tests for order creation, artisan notification, earnings, and order tracking."""
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
async def test_order_lifecycle(client: AsyncClient, db_session):
    # 1. Artisan creates a product
    artisan_token = await get_user_token(client, "+919222222222", "artisan", "Sunita Bai")
    artisan_headers = {"Authorization": f"Bearer {artisan_token}"}

    from product_helpers import seed_published_product
    product = await seed_published_product(
        client, db_session, artisan_headers, {
            "title_en": "Warli Tribal Canvas Painting",
            "price": 1200.0,
            "stock": 5,
            "status": "published",
        },
    )
    product_id = product["id"]

    # 2. Buyer places an order
    buyer_token = await get_user_token(client, "+919333333333", "buyer", "Amit Sharma")
    buyer_headers = {"Authorization": f"Bearer {buyer_token}"}

    order_payload = {
        "items": [{"product_id": product_id, "quantity": 2}],
        "shipping_address": {
            "name": "Amit Sharma",
            "phone": "+919333333333",
            "line1": "Flat 402, Lotus Towers, Andheri West",
            "city": "Mumbai",
            "state": "Maharashtra",
            "pincode": "400053",
        },
        "payment_method": "cod",
        "notes": "Please pack with extra care",
    }

    order_res = await client.post("/api/v1/orders", json=order_payload, headers=buyer_headers)
    assert order_res.status_code == 201
    order_data = order_res.json()
    assert order_data["total"] == 2400.0
    assert order_data["status"] == "pending"
    order_id = order_data["id"]

    # 3. Product stock should be decremented from 5 to 3
    prod_check = await client.get(f"/api/v1/products/{product_id}")
    assert prod_check.json()["stock"] == 3

    # 4. Artisan sees incoming order
    artisan_orders = await client.get("/api/v1/orders/artisan/me", headers=artisan_headers)
    assert artisan_orders.status_code == 200
    assert any(o["id"] == order_id for o in artisan_orders.json())

    # 5. Artisan checks notifications
    notif_res = await client.get("/api/v1/notifications", headers=artisan_headers)
    assert notif_res.status_code == 200
    assert len(notif_res.json()) >= 1
    assert "New Order" in notif_res.json()[0]["title"]

    # 6. Status transition: Accepted -> Shipped -> Delivered
    ship_res = await client.patch(
        f"/api/v1/orders/{order_id}/status",
        json={"status": "shipped"},
        headers=artisan_headers,
    )
    assert ship_res.status_code == 200
    assert ship_res.json()["status"] == "shipped"

    deliver_res = await client.patch(
        f"/api/v1/orders/{order_id}/status",
        json={"status": "delivered"},
        headers=artisan_headers,
    )
    assert deliver_res.status_code == 200
    assert deliver_res.json()["status"] == "delivered"

    # 7. Check earnings summary (earnings should now be settled minus 8% platform fee)
    earnings_res = await client.get("/api/v1/earnings/summary", headers=artisan_headers)
    assert earnings_res.status_code == 200
    earnings_data = earnings_res.json()
    assert earnings_data["settled_earnings"] == 2208.0
    assert earnings_data["total_orders_fulfilled"] == 1
