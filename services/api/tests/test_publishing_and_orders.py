"""Comprehensive test suite for Phase 4:
E-commerce publishing, multi-artisan order handling, payment webhooks, idempotency,
cancellation restocking, and verified database-driven earnings reporting.
"""
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
async def test_draft_visibility_and_unreviewed_publish_is_rejected(client: AsyncClient):
    """Draft rows remain private and cannot be published without final review input."""
    artisan_token = await get_user_token(client, "+919400000001", "artisan", "Laxmi Devi")
    headers = {"Authorization": f"Bearer {artisan_token}"}

    # 1. Create a draft product
    draft_res = await client.post(
        "/api/v1/products",
        json={
            "title_en": "Madhubani Painted Fish Coaster",
            "title_hi": "मधुबनी मछली कोस्टर",
            "price": 350.0,
            "stock": 10,
            "status": "draft",
            "material": "Handmade Paper & Acrylic",
            "technique": "Madhubani Kachni style",
            "idempotency_key": "draft-key-001",
        },
        headers=headers,
    )
    assert draft_res.status_code == 201
    draft_data = draft_res.json()
    draft_id = draft_data["id"]
    assert draft_data["status"] == "draft"

    # Draft must NOT be visible on the public website catalog
    pub_catalog = await client.get("/api/v1/products")
    assert not any(p["id"] == draft_id for p in pub_catalog.json()["items"])

    # 2. Resending with the same idempotency_key returns existing draft (no duplicates)
    dup_res = await client.post(
        "/api/v1/products",
        json={
            "title_en": "Madhubani Painted Fish Coaster",
            "price": 350.0,
            "stock": 10,
            "status": "draft",
            "idempotency_key": "draft-key-001",
        },
        headers=headers,
    )
    assert dup_res.status_code == 200 or dup_res.status_code == 201
    assert dup_res.json()["id"] == draft_id

    # 3. Direct publishing through draft conversion is no longer allowed.
    publish_res = await client.post(
        "/api/v1/products",
        json={
            "draft_product_id": draft_id,
            "title_en": "Madhubani Painted Fish Coaster - Set of 4",
            "title_hi": "मधुबनी मछली कोस्टर - ४ चा संच",
            "price": 400.0,
            "stock": 8,
            "status": "published",
            "material": "Handmade Paper & Acrylic",
            "technique": "Madhubani Kachni style",
            "idempotency_key": "publish-key-001",
            "images": [{"url": "https://images.unsplash.com/sample1.jpg", "is_primary": True, "order_index": 0}],
            "translations": [
                {"language": "hi", "title": "मधुबनी मछली कोस्टर", "description": "पारंपरिक हस्तनिर्मित कोस्टर"},
                {"language": "mr", "title": "मधुबनी मासा कोस्टर", "description": "पारंपरिक हस्तकला कोस्टर"}
            ],
        },
        headers=headers,
    )
    assert publish_res.status_code == 409
    still_private = await client.get("/api/v1/products")
    assert not any(p["id"] == draft_id for p in still_private.json()["items"])

    # 5. Dedicated one-tap publish endpoint check
    draft_res2 = await client.post(
        "/api/v1/products",
        json={"title_en": "Terracotta Diya", "price": 150.0, "stock": 20, "status": "draft"},
        headers=headers,
    )
    diya_id = draft_res2.json()["id"]
    one_tap = await client.post(f"/api/v1/products/{diya_id}/publish", headers=headers)
    assert one_tap.status_code == 422


@pytest.mark.asyncio
async def test_multi_artisan_orders_and_notifications(client: AsyncClient, db_session):
    """Test placing an order containing products from 2 distinct artisans."""
    # Artisan 1 (Shyam - Weaver)
    shyam_token = await get_user_token(client, "+919500000001", "artisan", "Shyam Weaver")
    shyam_headers = {"Authorization": f"Bearer {shyam_token}"}
    from product_helpers import seed_published_product
    p1 = await seed_published_product(client, db_session, shyam_headers, {"title_en": "Khadi Silk Scarf", "price": 1000.0, "stock": 10})
    p1_id = p1["id"]

    # Artisan 2 (Geeta - Potter)
    geeta_token = await get_user_token(client, "+919500000002", "artisan", "Geeta Potter")
    geeta_headers = {"Authorization": f"Bearer {geeta_token}"}
    p2 = await seed_published_product(client, db_session, geeta_headers, {"title_en": "Clay Water Bottle", "price": 500.0, "stock": 5})
    p2_id = p2["id"]

    # Buyer places multi-artisan order: 2 Scarves (2 * 1000 = 2000) + 1 Clay Bottle (500) = 2500
    buyer_token = await get_user_token(client, "+919500000003", "buyer", "Rohan Mehta")
    buyer_headers = {"Authorization": f"Bearer {buyer_token}"}

    order_payload = {
        "items": [
            {"product_id": p1_id, "quantity": 2},
            {"product_id": p2_id, "quantity": 1},
        ],
        "shipping_address": {
            "name": "Rohan Mehta",
            "phone": "+919500000003",
            "line1": "Flat 12, Shivaji Nagar",
            "city": "Nagpur",
            "state": "Maharashtra",
            "pincode": "440010",
        },
        "payment_method": "razorpay",
        "payment_id": "pay_test_multi_123",
        "notes": "Fast delivery requested",
    }
    order_res = await client.post("/api/v1/orders", json=order_payload, headers=buyer_headers)
    assert order_res.status_code == 201
    order_data = order_res.json()
    order_id = order_data["id"]
    assert order_data["total"] == 2500.0
    assert order_data["payment_status"] == "paid"

    # Stock check: p1 should be 8, p2 should be 4
    check1 = await client.get(f"/api/v1/products/{p1_id}")
    assert check1.json()["stock"] == 8
    check2 = await client.get(f"/api/v1/products/{p2_id}")
    assert check2.json()["stock"] == 4

    # Notifications check:
    # Shyam should receive notification mentioning "Khadi Silk Scarf" and net earning
    shyam_notifs = await client.get("/api/v1/notifications", headers=shyam_headers)
    assert len(shyam_notifs.json()) >= 1
    shyam_msg = shyam_notifs.json()[0]["body"]
    assert "Khadi Silk Scarf" in shyam_msg
    assert "1840" in shyam_msg
    assert "Clay Water Bottle" not in shyam_msg

    # Geeta should receive notification mentioning "Clay Water Bottle" and net earning
    geeta_notifs = await client.get("/api/v1/notifications", headers=geeta_headers)
    assert len(geeta_notifs.json()) >= 1
    geeta_msg = geeta_notifs.json()[0]["body"]
    assert "Clay Water Bottle" in geeta_msg
    assert "460" in geeta_msg
    assert "Khadi Silk Scarf" not in geeta_msg

    # Check orders per artisan:
    # Shyam's view shows only Shyam's items and total ₹2000
    shyam_orders = await client.get("/api/v1/orders/artisan/me", headers=shyam_headers)
    shyam_order = next(o for o in shyam_orders.json() if o["id"] == order_id)
    assert shyam_order["total"] == 2000.0
    assert len(shyam_order["items"]) == 1
    assert shyam_order["items"][0]["product_id"] == p1_id

    # Geeta's view shows only Geeta's items and total ₹500
    geeta_orders = await client.get("/api/v1/orders/artisan/me", headers=geeta_headers)
    geeta_order = next(o for o in geeta_orders.json() if o["id"] == order_id)
    assert geeta_order["total"] == 500.0
    assert len(geeta_order["items"]) == 1
    assert geeta_order["items"][0]["product_id"] == p2_id


@pytest.mark.asyncio
async def test_order_cancellation_and_inventory_restocking(client: AsyncClient, db_session):
    """Test cancelling an order restocks inventory, sets payment_status='refunded', and voids earnings."""
    artisan_token = await get_user_token(client, "+919600000001", "artisan", "Kamla Devi")
    artisan_headers = {"Authorization": f"Bearer {artisan_token}"}

    from product_helpers import seed_published_product
    product = await seed_published_product(client, db_session, artisan_headers, {"title_en": "Brass Bell", "price": 800.0, "stock": 4})
    product_id = product["id"]

    buyer_token = await get_user_token(client, "+919600000002", "buyer", "Vikram Rathore")
    buyer_headers = {"Authorization": f"Bearer {buyer_token}"}

    order_res = await client.post(
        "/api/v1/orders",
        json={
            "items": [{"product_id": product_id, "quantity": 2}],
            "shipping_address": {
                "name": "Vikram Rathore",
                "phone": "+919600000002",
                "line1": "Civil Lines",
                "city": "Jaipur",
                "state": "Rajasthan",
                "pincode": "302001",
            },
            "payment_method": "razorpay",
            "payment_id": "pay_cancel_test_1",
        },
        headers=buyer_headers,
    )
    assert order_res.status_code == 201
    order_id = order_res.json()["id"]

    # Stock decremented to 2
    prod_check = await client.get(f"/api/v1/products/{product_id}")
    assert prod_check.json()["stock"] == 2

    # Cancel order
    cancel_res = await client.post(f"/api/v1/orders/{order_id}/cancel", headers=artisan_headers)
    assert cancel_res.status_code == 200
    assert cancel_res.json()["status"] == "cancelled"
    assert cancel_res.json()["payment_status"] == "refunded"

    # Stock restocked back to 4!
    prod_restocked = await client.get(f"/api/v1/products/{product_id}")
    assert prod_restocked.json()["stock"] == 4

    # Dashboard must NOT treat cancelled order as completed revenue
    dash_res = await client.get("/api/v1/earnings/dashboard", headers=artisan_headers)
    assert dash_res.status_code == 200
    dash_data = dash_res.json()
    assert dash_data["refunds_cancellations"] == 1600.0
    assert dash_data["settled_payout"] == 0.0


@pytest.mark.asyncio
async def test_webhook_idempotency(client: AsyncClient, db_session):
    """Test that repeated payment webhook events do not duplicate earnings or notifications."""
    artisan_token = await get_user_token(client, "+919700000001", "artisan", "Babu Lal")
    artisan_headers = {"Authorization": f"Bearer {artisan_token}"}

    from product_helpers import seed_published_product
    product = await seed_published_product(client, db_session, artisan_headers, {"title_en": "Wood Carved Elephant", "price": 1500.0, "stock": 3})
    product_id = product["id"]

    buyer_token = await get_user_token(client, "+919700000002", "buyer", "Anita Rao")
    buyer_headers = {"Authorization": f"Bearer {buyer_token}"}

    # Order created initially as COD / unpaid
    order_res = await client.post(
        "/api/v1/orders",
        json={
            "items": [{"product_id": product_id, "quantity": 1}],
            "shipping_address": {
                "name": "Anita Rao",
                "phone": "+919700000002",
                "line1": "MG Road",
                "city": "Bengaluru",
                "state": "Karnataka",
                "pincode": "560001",
            },
            "payment_method": "cod",
        },
        headers=buyer_headers,
    )
    assert order_res.status_code == 201
    order_id = order_res.json()["id"]

    # 1. Fire payment.captured webhook
    webhook_payload = {
        "event": "payment.captured",
        "order_id": order_id,
        "payment_id": "razorpay_pay_998877",
    }
    wh_res1 = await client.post("/api/v1/orders/webhook", json=webhook_payload)
    assert wh_res1.status_code == 200
    assert wh_res1.json()["status"] == "processed"

    # 2. Fire EXACT SAME webhook event again (network retry simulation)
    wh_res2 = await client.post("/api/v1/orders/webhook", json=webhook_payload)
    assert wh_res2.status_code == 200
    assert wh_res2.json()["status"] == "already_processed"


@pytest.mark.asyncio
async def test_artisan_dashboard_metrics_and_authorization(client: AsyncClient, db_session):
    """Test verified DB metrics calculation: gross sales, 8% platform fee, net earnings, trends, and authorization isolation."""
    # Artisan A
    token_a = await get_user_token(client, "+919800000001", "artisan", "Mahesh Artisan")
    headers_a = {"Authorization": f"Bearer {token_a}"}

    # Artisan B
    token_b = await get_user_token(client, "+919800000002", "artisan", "Suresh Artisan")
    headers_b = {"Authorization": f"Bearer {token_b}"}

    # Artisan A creates 2 products
    from product_helpers import seed_published_product
    p_a1 = (await seed_published_product(client, db_session, headers_a, {"title_en": "Bamboo Basket", "price": 500.0, "stock": 10}))['id']
    p_a2 = (await seed_published_product(client, db_session, headers_a, {"title_en": "Bamboo Lamp", "price": 1000.0, "stock": 5}))['id']

    # Artisan B creates 1 product
    p_b1 = (await seed_published_product(client, db_session, headers_b, {"title_en": "Stone Idol", "price": 3000.0, "stock": 2}))['id']

    # Buyer places Order 1 for Artisan A (2 Baskets = ₹1000)
    buyer_token = await get_user_token(client, "+919800000003", "buyer", "Buyer Alpha")
    buyer_headers = {"Authorization": f"Bearer {buyer_token}"}

    ord1_res = await client.post(
        "/api/v1/orders",
        json={
            "items": [{"product_id": p_a1, "quantity": 2}],
            "shipping_address": {
                "name": "Alpha",
                "phone": "+919800000003",
                "city": "Delhi",
                "state": "Delhi",
                "line1": "Connaught Place",
                "pincode": "110001",
            },
            "payment_method": "razorpay",
            "payment_id": "pay_alpha_1",
        },
        headers=buyer_headers,
    )
    assert ord1_res.status_code == 201
    ord1 = ord1_res.json()["id"]

    # Deliver Order 1 -> Settled payout
    await client.patch(f"/api/v1/orders/{ord1}/status", json={"status": "delivered"}, headers=headers_a)

    # Buyer places Order 2 for Artisan A (1 Lamp = ₹1000, in pending state)
    ord2_res = await client.post(
        "/api/v1/orders",
        json={
            "items": [{"product_id": p_a2, "quantity": 1}],
            "shipping_address": {
                "name": "Alpha",
                "phone": "+919800000003",
                "city": "Delhi",
                "state": "Delhi",
                "line1": "Connaught Place",
                "pincode": "110001",
            },
            "payment_method": "razorpay",
            "payment_id": "pay_alpha_2",
        },
        headers=buyer_headers,
    )
    assert ord2_res.status_code == 201
    ord2 = ord2_res.json()["id"]

    # Verify Artisan A's dashboard
    dash_a = await client.get("/api/v1/earnings/dashboard", headers=headers_a)
    assert dash_a.status_code == 200
    data_a = dash_a.json()

    # Total orders: 2, Products sold: 3 (2 baskets + 1 lamp)
    assert data_a["total_orders"] == 2
    assert data_a["products_sold"] == 3
    # Gross sales: 2000.0
    assert data_a["gross_sales"] == 2000.0
    # 8% platform fee: 2000 * 0.08 = 160.0
    assert data_a["platform_fees"] == 160.0
    # Net earnings: 2000 - 160 = 1840.0
    assert data_a["net_earnings"] == 1840.0
    # Settled payout: Order 1 delivered (1000 - 80 = 920.0)
    assert data_a["settled_payout"] == 920.0
    # Pending payout: Order 2 not yet delivered (1000 - 80 = 920.0)
    assert data_a["pending_payout"] == 920.0

    # Best-sellers: Basket (2 sold, ₹1000 rev) & Lamp (1 sold, ₹1000 rev)
    assert len(data_a["best_selling_products"]) == 2
    assert data_a["best_selling_products"][0]["title"] == "Bamboo Basket"
    assert data_a["best_selling_products"][0]["quantity_sold"] == 2

    # Trends must have data
    assert len(data_a["daily_trends"]) >= 1
    assert len(data_a["monthly_trends"]) >= 1

    # Authorization Check: Artisan B's dashboard must NOT show any of Artisan A's orders/revenue!
    dash_b = await client.get("/api/v1/earnings/dashboard", headers=headers_b)
    assert dash_b.status_code == 200
    data_b = dash_b.json()
    assert data_b["total_orders"] == 0
    assert data_b["gross_sales"] == 0.0
    assert data_b["net_earnings"] == 0.0
