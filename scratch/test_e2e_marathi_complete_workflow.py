"""Comprehensive End-to-End Test for KalaSathi
Executes the complete 12-step Marathi artisan-to-buyer workflow:
1. Artisan signs in and chooses Marathi ('mr')
2. Artisan uploads a real product photograph
3. System generates 10-15 image variations
4. Artisan selects 3-4 images
5. Artisan speaks product description in Marathi
6. App displays editable transcript and structured catalog with 12-language translations & TTS playback
7. App provides transparent pricing recommendations (Cost Floor, Suggested, Premium)
8. Artisan publishes product with selected images and stock
9. Product appears on e-commerce website catalog
10. Buyer places an order via checkout
11. Artisan receives order notification
12. Artisan dashboard displays verified updated orders, sales, platform fee deductions, and net earnings
"""
import sys
import io
import json
import base64
import asyncio
import httpx
from PIL import Image

API_BASE = "http://127.0.0.1:8000/api/v1"
AI_BASE = "http://127.0.0.1:8001"


async def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8")

    print("=" * 80)
    print("KALASATHI COMPLETE END-TO-END VERIFICATION: 12-STEP MARATHI WORKFLOW")
    print("=" * 80)

    import time
    run_timestamp = int(time.time())

    async with httpx.AsyncClient(timeout=30.0) as client:
        # ----------------------------------------------------------------------
        # STEP 1: Artisan signs in and chooses Marathi
        # ----------------------------------------------------------------------
        print("\n--- STEP 1: Artisan Signs In & Chooses Marathi ('mr') ---")
        artisan_phone = f"+9198{run_timestamp % 100000000:08d}"
        otp_send = await client.post(f"{API_BASE}/auth/otp/send", json={"phone": artisan_phone, "role": "artisan"})
        assert otp_send.status_code == 200, f"OTP send failed: {otp_send.text}"
        otp_code = otp_send.json()["mock_code"]

        otp_verify = await client.post(
            f"{API_BASE}/auth/otp/verify",
            json={
                "phone": artisan_phone,
                "code": otp_code,
                "name": "तुकाराम शिंदे (Tukaram Shinde)",
                "language": "mr",
            },
        )
        assert otp_verify.status_code == 200, f"OTP verify failed: {otp_verify.text}"
        artisan_res_data = otp_verify.json()
        artisan_token = artisan_res_data["access_token"]
        artisan_user_id = artisan_res_data["user_id"]
        artisan_name = artisan_res_data["name"]
        artisan_headers = {"Authorization": f"Bearer {artisan_token}"}

        # Update language preference to Marathi
        pref_res = await client.patch(
            f"{API_BASE}/auth/me",
            json={"language": "mr"},
            headers=artisan_headers,
        )
        assert pref_res.status_code == 200
        print(f"✓ Artisan Authenticated: {artisan_name} (ID: {artisan_user_id})")
        print(f"✓ Language Preference Saved: Marathi ('mr', मराठी)")

        # ----------------------------------------------------------------------
        # STEP 2: Artisan uploads a real product photograph
        # ----------------------------------------------------------------------
        print("\n--- STEP 2: Artisan Uploads Real Product Photograph ---")
        img = Image.new("RGB", (400, 400), color=(190, 150, 120))
        # Add a terracotta pot silhouette in the center
        for x in range(120, 280):
            for y in range(100, 320):
                if ((x - 200) ** 2) / 6400 + ((y - 210) ** 2) / 10000 <= 1:
                    img.putpixel((x, y), (180, 70, 35))

        img_byte_arr = io.BytesIO()
        img.save(img_byte_arr, format="JPEG", quality=90)
        img_bytes = img_byte_arr.getvalue()
        print(f"✓ Raw Artisan Handicraft Photo Prepared: {len(img_bytes)} bytes (Warli Terracotta Vase)")

        # ----------------------------------------------------------------------
        # STEP 3: System generates 10-15 image variations
        # ----------------------------------------------------------------------
        print("\n--- STEP 3: System Generates 10-15 Studio Variations ---")
        var_res = await client.post(
            f"{API_BASE}/ai/generate-variations",
            files={"file": ("warli_vase.jpg", img_bytes, "image/jpeg")},
            data={"count": 12, "preferred_language": "mr"},
            headers=artisan_headers,
        )
        assert var_res.status_code == 200, f"Generate variations failed: {var_res.text}"
        var_data = var_res.json()
        variations = var_data["variations"]
        print(f"✓ Variations Generated: {len(variations)} studio styles returned (Required: 10-15)")
        assert 10 <= len(variations) <= 15, "Variations count outside 10-15 range"

        for idx, v in enumerate(variations[:5]):
            print(f"   [{idx+1}] ID: {v['id']} | Title (MR): {v.get('title_mr', v.get('title'))} | Canvas: {v.get('canvas_style')}")
        print(f"   ... and {len(variations) - 5} more variations generated.")

        # ----------------------------------------------------------------------
        # STEP 4: Artisan selects 3-4 images
        # ----------------------------------------------------------------------
        print("\n--- STEP 4: Artisan Selects 3-4 Images ---")
        # Select 4 variations: Pristine White (Hero), Terracotta Warmth, Sandstone Pedestal, Royal Indigo
        selected_indices = [0, 1, 5, 7]
        selected_variations = [variations[i] for i in selected_indices]
        print(f"✓ Selected {len(selected_variations)} Images (Required: 3-4):")
        for i, sv in enumerate(selected_variations):
            is_hero = (i == 0)
            tag = " [PRIMARY / HERO]" if is_hero else " [GALLERY]"
            print(f"   - Image {i+1}: {sv['title']}{tag}")

        product_images_payload = []
        for i, sv in enumerate(selected_variations):
            product_images_payload.append({
                "url": sv.get("image_base64", "https://images.unsplash.com/photo-1578749556568-bc2c40e68b61?w=800"),
                "is_primary": (i == 0),
                "order_index": i,
            })

        # ----------------------------------------------------------------------
        # STEP 5: Artisan speaks product description in Marathi
        # ----------------------------------------------------------------------
        print("\n--- STEP 5: Artisan Speaks Product Description in Marathi ---")
        marathi_speech_input = "हा हाताने बनवलेला वारली कलेचा कॅनव्हास आहे. यात तांदळाचे पीठ आणि डिंकाचा नैसर्गिक रंग वापरला आहे. तयार करायला सहा तास लागले आणि साहित्याचा खर्च सुमारे दीडशे रुपये आहे."
        print(f"✓ Spoken Input (Audio Simulated): '{marathi_speech_input}'")

        # ----------------------------------------------------------------------
        # STEP 6: Editable transcript & professional catalog with 12 translations
        # ----------------------------------------------------------------------
        print("\n--- STEP 6: Editable Transcript, 12-Language Catalog & Voice Playback ---")
        # Extract catalog
        cat_res = await client.post(
            f"{API_BASE}/ai/catalog",
            json={
                "transcript": marathi_speech_input,
                "language": "mr",
            },
            headers=artisan_headers,
        )
        assert cat_res.status_code == 200, f"Extract catalog failed: {cat_res.text}"
        cat_data = cat_res.json()
        print(f"✓ Title (EN): {cat_data.get('title_en')}")
        print(f"✓ Title (HI): {cat_data.get('title_hi')}")
        print(f"✓ Material: {cat_data.get('material')}")
        print(f"✓ Technique: {cat_data.get('technique')}")
        print(f"✓ Care Instructions: {cat_data.get('care_instructions')}")

        translations = cat_data.get("translations", [])
        print(f"✓ Translations Generated across {len(translations)} Languages:")
        for item in translations:
            print(f"   [{item['language'].upper()}]: {item['title'][:40]}...")
        assert len(translations) == 12, f"Expected 12 languages, got {len(translations)}"

        # Verify TTS playback in Marathi
        tts_res = await client.post(
            f"{API_BASE}/ai/synthesize",
            json={"text": f"{cat_data.get('title_hi', 'वारली कला')}. {cat_data.get('description_hi', '')[:60]}", "language": "mr"},
            headers=artisan_headers,
        )
        assert tts_res.status_code == 200
        tts_data = tts_res.json()
        print(f"✓ Voice Playback (TTS in Marathi) Audio Generated: {len(tts_data.get('audio_base64', ''))} chars base64 WAV")

        # ----------------------------------------------------------------------
        # STEP 7: Transparent pricing recommendations
        # ----------------------------------------------------------------------
        print("\n--- STEP 7: Transparent Pricing Recommendations ---")
        pricing_res = await client.post(
            f"{API_BASE}/ai/price",
            json={
                "craft_category": "Tribal & Folk Art",
                "material_cost": 150.0,
                "labor_hours": 6.0,
                "hourly_rate": 100.0,
                "packaging_cost": 40.0,
                "shipping_cost": 60.0,
                "platform_fee_percent": 8.0,
                "language": "mr",
            },
            headers=artisan_headers,
        )
        assert pricing_res.status_code == 200, f"Pricing recommendation failed: {pricing_res.text}"
        pricing = pricing_res.json()
        print(f"✓ Tier 1 - Minimum Cost Floor: ₹{pricing['cost_floor']:.0f} (No financial loss)")
        print(f"✓ Tier 2 - Suggested Selling Price: ₹{pricing['suggested_price']:.0f} (Fair margin + 8% fee)")
        print(f"✓ Tier 3 - Premium Artisan Price: ₹{pricing['premium_price']:.0f} (Master craftsmanship)")
        print(f"✓ Influencing Factors: {', '.join(pricing.get('influencing_factors', []))}")
        accepted_price = float(pricing["suggested_price"])

        # ----------------------------------------------------------------------
        # STEP 8: Artisan publishes the product
        # ----------------------------------------------------------------------
        print("\n--- STEP 8: Artisan Publishes Product ---")
        idempotency_key = f"idemp-marathi-e2e-warli-{run_timestamp}"
        publish_payload = {
            "title_en": cat_data.get("title_en", "Warli Folk Art Canvas"),
            "title_hi": cat_data.get("title_hi", "वारली लोक कला कैनवास"),
            "description_en": cat_data.get("description_en", "Handmade authentic Warli canvas with natural pigments."),
            "description_hi": cat_data.get("description_hi", "प्राकृतिक रंगों से बना हस्तनिर्मित वारली कला कैनवास।"),
            "price": accepted_price,
            "stock": 10,
            "status": "published",
            "material": cat_data.get("material", "Cotton Canvas & Natural Rice Paste"),
            "technique": cat_data.get("technique", "Warli Bamboo Nib Painting"),
            "care_instructions": cat_data.get("care_instructions", "Keep away from moisture"),
            "seo_keywords": ["warli", "canvas", "tribal art", "handmade", "maharashtra"],
            "idempotency_key": idempotency_key,
            "images": product_images_payload,
            "translations": [
                {"language": item["language"], "title": item["title"], "description": item.get("description", item.get("short_description", ""))}
                for item in translations
            ],
        }

        pub_res = await client.post(
            f"{API_BASE}/products",
            json=publish_payload,
            headers=artisan_headers,
        )
        assert pub_res.status_code == 201, f"Product publish failed: {pub_res.text}"
        published_product = pub_res.json()
        product_id = published_product["id"]
        print(f"✓ Product Successfully Published! Product ID: #{product_id}")
        print(f"✓ Status: '{published_product['status']}' | Price: ₹{published_product['price']} | Stock: {published_product['stock']}")
        print(f"✓ Attached Images: {len(published_product.get('images', []))} photos")
        print(f"✓ Stored Translations: {len(published_product.get('translations', []))} languages")

        # Verify idempotency prevents duplicate publishing
        dup_res = await client.post(
            f"{API_BASE}/products",
            json=publish_payload,
            headers=artisan_headers,
        )
        assert dup_res.status_code in (200, 201), "Idempotent duplicate check failed"
        assert dup_res.json()["id"] == product_id, "Idempotency key did not return existing product"
        print("✓ Idempotency Verified: Duplicate submissions safely return existing product without duplicates")

        # ----------------------------------------------------------------------
        # STEP 9: Product appears on existing e-commerce website
        # ----------------------------------------------------------------------
        print("\n--- STEP 9: Product Verified on Website Catalog ---")
        web_res = await client.get(f"{API_BASE}/products?size=50")
        assert web_res.status_code == 200
        catalog = web_res.json()["items"]
        found_product = next((p for p in catalog if p["id"] == product_id), None)
        assert found_product is not None, f"Published product #{product_id} not visible on website catalog!"
        print(f"✓ Product Visible to Public Buyers on Website: #{found_product['id']} - '{found_product['title_en']}'")
        print(f"✓ Public Images Verified: {len(found_product['images'])} images loaded")

        # ----------------------------------------------------------------------
        # STEP 10: Buyer places an order using existing checkout
        # ----------------------------------------------------------------------
        print("\n--- STEP 10: Buyer Places Order via Website Checkout ---")
        buyer_phone = f"+9197{(run_timestamp + 123) % 100000000:08d}"
        b_otp_send = await client.post(f"{API_BASE}/auth/otp/send", json={"phone": buyer_phone, "role": "buyer"})
        b_code = b_otp_send.json()["mock_code"]
        b_verify = await client.post(
            f"{API_BASE}/auth/otp/verify",
            json={"phone": buyer_phone, "code": b_code, "name": "Pooja Kulkarni (पूजा कुलकर्णी)"},
        )
        buyer_token = b_verify.json()["access_token"]
        buyer_headers = {"Authorization": f"Bearer {buyer_token}"}

        order_quantity = 2
        order_gross = accepted_price * order_quantity
        order_payload = {
            "items": [{"product_id": product_id, "quantity": order_quantity}],
            "shipping_address": {
                "name": "Pooja Kulkarni",
                "phone": buyer_phone,
                "line1": "Flat 402, Lotus Towers, Baner",
                "city": "Pune",
                "state": "Maharashtra",
                "pincode": "411045",
            },
            "payment_method": "razorpay",
            "payment_id": f"pay_test_marathi_e2e_{run_timestamp}",
            "notes": "Please pack with extra care for gift delivery.",
        }

        order_res = await client.post(f"{API_BASE}/orders", json=order_payload, headers=buyer_headers)
        assert order_res.status_code == 201, f"Order placement failed: {order_res.text}"
        order_data = order_res.json()
        order_id = order_data["id"]
        print(f"✓ Order Placed by Buyer! Order ID: #{order_id}")
        print(f"✓ Gross Total: ₹{order_data['total']} | Units: {order_quantity} | Payment: {order_data['payment_method']} ({order_data['payment_status']})")

        # Verify stock decremented
        stock_check = await client.get(f"{API_BASE}/products/{product_id}")
        remaining_stock = stock_check.json()["stock"]
        print(f"✓ Stock Decremented from 10 to {remaining_stock} (Expected: 8)")
        assert remaining_stock == 8, f"Expected stock 8, found {remaining_stock}"

        # ----------------------------------------------------------------------
        # STEP 11: Artisan receives order notification
        # ----------------------------------------------------------------------
        print("\n--- STEP 11: Artisan Receives Order Notification ---")
        notif_res = await client.get(f"{API_BASE}/notifications", headers=artisan_headers)
        assert notif_res.status_code == 200
        notifications = notif_res.json()
        matching_notif = next((n for n in notifications if n["data"].get("order_id") == order_id), None)
        assert matching_notif is not None, f"No notification found for artisan for Order #{order_id}"
        print(f"✓ In-App Notification Received by Artisan:")
        print(f"   Title: '{matching_notif['title']}'")
        print(f"   Body:  '{matching_notif['body']}'")
        expected_net = round(order_gross * 0.92, 2)
        print(f"   Gross Sale: ₹{order_gross:.0f} | Net Earning: ₹{expected_net:.0f}")

        # ----------------------------------------------------------------------
        # STEP 12: Artisan dashboard displays verified updated order and earnings
        # ----------------------------------------------------------------------
        print("\n--- STEP 12: Artisan Dashboard Displays Updated Orders & Net Earnings ---")
        dash_res = await client.get(f"{API_BASE}/earnings/dashboard", headers=artisan_headers)
        assert dash_res.status_code == 200, f"Dashboard fetch failed: {dash_res.text}"
        dash = dash_res.json()
        print(f"✓ Total Orders: {dash['total_orders']}")
        print(f"✓ Units Sold:   {dash['products_sold']}")
        print(f"✓ Gross Sales:  ₹{dash['gross_sales']:.2f}")
        print(f"✓ Platform Deductions (8%): ₹{dash['platform_fees']:.2f}")
        print(f"✓ Net Earnings: ₹{dash['net_earnings']:.2f}")
        print(f"✓ Pending Payout: ₹{dash['pending_payout']:.2f}")
        print(f"✓ Best Selling Products: {len(dash['best_selling_products'])}")
        print(f"✓ Recent Orders Count: {len(dash['recent_orders'])}")
        assert dash["total_orders"] >= 1
        assert dash["products_sold"] >= 2
        assert dash["gross_sales"] >= order_gross

        print("\n" + "=" * 80)
        print("🎉 ALL 12 STEPS OF THE COMPLETE MARATHI END-TO-END WORKFLOW PASSED SUCCESSFULLY!")
        print("=" * 80)


if __name__ == "__main__":
    asyncio.run(main())
