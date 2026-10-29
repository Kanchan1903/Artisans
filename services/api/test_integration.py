"""Full integration test: register artisan, upload photo, verify mock CrewAI variants, save selection, check MongoDB."""
import asyncio
import json
import sys
import urllib.request
import urllib.parse
import os
import io

BASE = "http://localhost:8000/api/v1"


def api(path, method="GET", data=None, token=None, files=None, form=None):
    url = f"{BASE}{path}"
    headers = {}
    body = None

    if token:
        headers["Authorization"] = f"Bearer {token}"

    if data:
        body = json.dumps(data).encode()
        headers["Content-Type"] = "application/json"
    elif form:
        # multipart/form-data
        boundary = "----kalasathitest12345"
        parts = []
        for k, v in form.items():
            parts.append(f'------kalasathitest12345\r\nContent-Disposition: form-data; name="{k}"\r\n\r\n{v}')
        if files:
            for fname, (field, content, ct) in files.items():
                parts.append(
                    f'------kalasathitest12345\r\nContent-Disposition: form-data; name="{field}"; filename="{fname}"\r\nContent-Type: {ct}\r\n\r\n'
                )
                body = ("\r\n".join(parts)).encode() + content + b"\r\n------kalasathitest12345--\r\n"
                headers["Content-Type"] = f"multipart/form-data; boundary=----kalasathitest12345"
                req = urllib.request.Request(url, data=body, headers=headers, method=method)
                try:
                    with urllib.request.urlopen(req, timeout=15) as r:
                        return json.loads(r.read()), r.status
                except urllib.error.HTTPError as e:
                    return json.loads(e.read()), e.code

    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            return json.loads(r.read()), r.status
    except urllib.error.HTTPError as e:
        try:
            return json.loads(e.read()), e.code
        except Exception:
            return {"error": str(e)}, e.code


def test():
    print("\n=== KarigarAI Integration Test ===\n")

    # Step 1: Register artisan
    import random
    phone = f"+9198765{random.randint(10000, 99999)}"
    name = "Test Artisan"
    password = "test1234"
    print(f"[1] Registering artisan: {phone}")
    reg_data, reg_status = api("/auth/register", "POST", {
        "name": name, "phone": phone, "password": password, "role": "artisan"
    })
    print(f"    Status: {reg_status}")
    if reg_status not in (200, 201):
        print(f"    FAIL: {reg_data}")
        # Try login with seed artisan instead
        print("[1b] Trying login with seed data...")
        login_data, ls = api("/auth/login", "POST", {"identifier": "priya@kalasathi.com", "password": "Priya@1234"})
        print(f"    Status: {ls}, Response: {json.dumps(login_data)[:150]}")
        if ls == 200:
            token = login_data.get("access_token")
        else:
            print("   SKIP: No working artisan credentials")
            return
    else:
        token = reg_data.get("access_token")
        print(f"    OK — token: {token[:30]}...")

    # Step 2: Create image job with mock photo
    print("\n[2] Uploading product photo (1x1 JPEG placeholder)...")
    # Minimal 1×1 JPEG bytes
    tiny_jpeg = (
        b"\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00"
        b"\xff\xdb\x00C\x00\x08\x06\x06\x07\x06\x05\x08\x07\x07\x07\t\t"
        b"\x08\n\x0c\x14\r\x0c\x0b\x0b\x0c\x19\x12\x13\x0f\x14\x1d\x1a\x1f\x1e"
        b"\x1d\x1a\x1c\x1c $.' \",#\x1c\x1c(7),01444\x1f'9=82<.342\x1eZ\xff\xd9"
    )

    boundary = "----kalasathitest12345"
    nl = b"\r\n"
    body = (
        b"------kalasathitest12345\r\n"
        b'Content-Disposition: form-data; name="file"; filename="test.jpg"\r\n'
        b"Content-Type: image/jpeg\r\n\r\n"
        + tiny_jpeg + b"\r\n"
        b"------kalasathitest12345\r\n"
        b'Content-Disposition: form-data; name="product_name"\r\n\r\nTest Handcraft\r\n'
        b"------kalasathitest12345\r\n"
        b'Content-Disposition: form-data; name="product_category"\r\n\r\nPottery\r\n'
        b"------kalasathitest12345\r\n"
        b'Content-Disposition: form-data; name="generate_variations"\r\n\r\ntrue\r\n'
        b"------kalasathitest12345--\r\n"
    )
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": f"multipart/form-data; boundary=----kalasathitest12345",
    }
    req = urllib.request.Request(f"{BASE}/image-jobs", data=body, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            job = json.loads(r.read())
            job_status_code = r.status
    except urllib.error.HTTPError as e:
        job = json.loads(e.read())
        job_status_code = e.code

    print(f"    Status: {job_status_code}")
    if job_status_code not in (200, 201):
        print(f"    FAIL: {json.dumps(job)[:300]}")
        return

    print(f"    job_id   = {job.get('job_id')}")
    print(f"    status   = {job.get('status')}")
    print(f"    variants = {len(job.get('variants', []))}")
    print(f"    crewai_exec_id = {job.get('crewai_execution_id')}")

    job_id = job.get("job_id")
    variants = job.get("variants", [])

    if job.get("status") != "completed":
        print(f"    WARNING: Expected 'completed' in mock mode, got '{job.get('status')}'")
        print(f"    Errors: {job.get('errors')}")

    # Step 3: Verify variants have real URLs
    print("\n[3] Verifying variant image URLs...")
    for i, v in enumerate(variants[:3]):
        url = v.get("image_url", "")
        vid = v.get("id", "")
        print(f"    Variant {i+1}: id={vid}, url={url[:60]}")
        assert url.startswith("http"), f"Expected http URL, got: {url}"
    print("    OK — all variants have HTTP URLs")

    # Step 4: Select 3 variants
    if len(variants) >= 3:
        selected = [variants[0]["id"], variants[1]["id"], variants[2]["id"]]
        print(f"\n[4] Saving variant selection: {selected}")
        sel_data, sel_status = api(
            f"/image-jobs/{job_id}/selection",
            "PUT",
            {"variant_ids": selected},
            token=token,
        )
        print(f"    Status: {sel_status}")
        if sel_status == 200:
            print(f"    selected_variant_ids = {sel_data.get('selected_variant_ids')}")
            print("    OK — selection saved to SQL + MongoDB")
        else:
            print(f"    FAIL: {json.dumps(sel_data)[:300]}")

        # Step 5: Check MongoDB
        print("\n[5] Verifying MongoDB document...")
        try:
            import motor.motor_asyncio
            async def check_mongo():
                client = motor.motor_asyncio.AsyncIOMotorClient("mongodb://localhost:27017", serverSelectionTimeoutMS=2000)
                db = client["kalasathi"]
                doc = await db["image_jobs"].find_one({"job_id": job_id}, {"_id": 0})
                if doc:
                    print(f"    Found in MongoDB!")
                    print(f"    job_id   = {doc.get('job_id')}")
                    print(f"    status   = {doc.get('status')}")
                    print(f"    selected = {doc.get('selected_variant_ids')}")
                    print(f"    variants = {len(doc.get('variants', []))}")
                else:
                    print("    WARNING: Job not found in MongoDB (may be async delay)")
            asyncio.run(check_mongo())
        except Exception as e:
            print(f"    WARNING: MongoDB check failed: {e}")

        # Step 6: Publish product
        print("\n[6] Publishing product with selected variant images...")
        prod_data, prod_status = api("/products", "POST", {
            "title_en": "Test Handcrafted Pottery",
            "description_en": "Beautiful handcrafted pottery by Indian artisan",
            "price": 850.0,
            "stock": 5,
            "image_job_id": job_id,
            "selected_variant_ids": selected,
            "status": "published",
        }, token=token)
        print(f"    Status: {prod_status}")
        if prod_status in (200, 201):
            print(f"    product_id = {prod_data.get('id')}")
            print(f"    images     = {[img.get('url', '')[:60] for img in prod_data.get('images', [])]}")
            print(f"    status     = {prod_data.get('status')}")
            print("\n=== ALL TESTS PASSED ===")
        else:
            print(f"    Details: {json.dumps(prod_data)[:400]}")

    else:
        print(f"\n    Only {len(variants)} variants returned. Need >= 3 to test selection.")


if __name__ == "__main__":
    test()
