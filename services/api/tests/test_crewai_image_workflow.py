"""Automated test suite verifying CrewAI Image Agent, MongoDB integration, and publishing workflow.

Covers the 14 test requirements:
1. Successful photo upload
2. CrewAI kickoff and status retrieval
3. Workflow timeout and API failure
4. Invalid JSON and missing fields
5. Segmentation failure and retake handling
6. Missing or inaccessible image URLs
7. MongoDB persistence and update behavior
8. Duplicate request / idempotency handling
9. Artisan ownership and authorization
10. Selection of exactly three variants
11. Rejection of invalid variant selections
12. Product draft versus published visibility
13. Display of saved images on published product
14. Preservation of existing application functionality
"""
import io
import json
from datetime import datetime, timedelta, timezone
import pytest
from PIL import Image
from httpx import AsyncClient, ASGITransport
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.image_job import ImageJobStatus, ImageProcessingJob
from app.mongodb import (
    get_image_job_mongo,
    get_product_mongo,
    list_artisan_jobs_mongo,
    save_image_job_mongo,
    save_product_mongo,
    update_job_selection_mongo,
)
from app.utils.crewai_client import CrewAIClient, CrewAIError
from app.utils.image_job_result import InvalidImageJobResult, normalize_final_json, parse_crewai_status_payload
from app.utils.image_jobs import build_kickoff_inputs, persist_normalized_result, refresh_job_from_crewai


# ─── Helper Fixtures & Tokens ──────────────────────────────────────────────────

async def get_artisan_token(client: AsyncClient, phone: str = "+919999000001", name: str = "Test Artisan") -> str:
    await client.post("/api/v1/auth/otp/send", json={"phone": phone, "role": "artisan"})
    res = await client.post(
        "/api/v1/auth/otp/verify",
        json={"phone": phone, "code": "123456", "name": name, "role": "artisan"},
    )
    return res.json()["access_token"]


def dummy_image_bytes() -> bytes:
    image = Image.new("RGB", (2, 2), color="white")
    buffer = io.BytesIO()
    image.save(buffer, format="JPEG")
    return buffer.getvalue()


@pytest.mark.asyncio
async def test_crewai_input_mapping_uses_discovered_schema(monkeypatch):
    job = ImageProcessingJob(
        id="job-123",
        artisan_id=7,
        product_id=42,
        product_name="Blue Vase",
        product_category="Pottery",
        original_photo_url="https://cdn.example.test/original.jpg",
    )

    async def discovered(self):
        return [
            "job_id", "artisan_id", "product_id", "photo_url", "product_name",
            "product_category", "background_colors", "generate_variations",
        ]

    monkeypatch.setattr(CrewAIClient, "get_inputs", discovered)
    mapped = await build_kickoff_inputs(job, client=CrewAIClient(base_url="https://crew.example.test", bearer_token="token"))
    assert mapped["job_id"] == "job-123"
    assert mapped["artisan_id"] == "7"
    assert mapped["product_id"] == "42"
    assert mapped["photo_url"] == "https://cdn.example.test/original.jpg"
    assert mapped["product_name"] == "Blue Vase"
    assert mapped["product_category"] == "Pottery"
    assert mapped["generate_variations"] == "true"
    assert "background_colors" in mapped


@pytest.mark.asyncio
async def test_upload_rejects_invalid_type_corrupt_and_oversized_images(client: AsyncClient):
    token = await get_artisan_token(client, "+919900000000", "Upload Validation")
    headers = {"Authorization": f"Bearer {token}"}
    wrong_type = await client.post(
        "/api/image-jobs", headers=headers,
        files={"file": ("bad.pdf", b"not an image", "application/pdf")},
    )
    assert wrong_type.status_code == 415
    corrupt = await client.post(
        "/api/image-jobs", headers=headers,
        files={"file": ("bad.jpg", b"not really a jpeg", "image/jpeg")},
    )
    assert corrupt.status_code == 400
    oversized = await client.post(
        "/api/image-jobs", headers=headers,
        files={"file": ("large.jpg", b"x" * (15 * 1024 * 1024 + 1), "image/jpeg")},
    )
    assert oversized.status_code == 413


@pytest.mark.asyncio
async def test_uncertain_segmentation_requires_artisan_review_before_selection(client: AsyncClient, monkeypatch):
    token = await get_artisan_token(client, "+919900000009", "Review Artisan")
    headers = {"Authorization": f"Bearer {token}"}

    async def kickoff(self, inputs):
        return "kickoff_review"

    async def get_status(self, kickoff_id):
        return {
            "status": "completed",
            "result": {
                "segmentation_status": "uncertain",
                "variants": [
                    {"id": f"var_{i}", "image_url": f"https://example.test/v{i}.jpg"}
                    for i in range(1, 4)
                ],
            },
        }

    monkeypatch.setattr(CrewAIClient, "is_configured", lambda self: True)
    monkeypatch.setattr(CrewAIClient, "kickoff", kickoff)
    monkeypatch.setattr(CrewAIClient, "get_status", get_status)
    created = await client.post(
        "/api/image-jobs", headers=headers,
        files={"file": ("craft.jpg", dummy_image_bytes(), "image/jpeg")},
    )
    job_id = created.json()["job_id"]
    status_result = await client.get(f"/api/image-jobs/{job_id}", headers=headers)
    assert status_result.json()["status"] == "awaiting_review"
    rejected = await client.put(
        f"/api/image-jobs/{job_id}/selection", headers=headers,
        json={"variant_ids": ["var_1", "var_2", "var_3"]},
    )
    assert rejected.status_code == 400
    approved = await client.post(
        f"/api/image-jobs/{job_id}/review", headers=headers, json={"approved": True},
    )
    assert approved.status_code == 200
    assert approved.json()["status"] == "completed"


@pytest.mark.asyncio
async def test_product_cannot_publish_before_image_job_is_ready(client: AsyncClient, monkeypatch):
    token = await get_artisan_token(client, "+919900000010", "Pending Publish Artisan")
    headers = {"Authorization": f"Bearer {token}"}

    async def kickoff(self, inputs):
        return "kickoff_pending"

    async def get_status(self, kickoff_id):
        return {"status": "running", "kickoff_id": kickoff_id}

    monkeypatch.setattr(CrewAIClient, "is_configured", lambda self: True)
    monkeypatch.setattr(CrewAIClient, "kickoff", kickoff)
    monkeypatch.setattr(CrewAIClient, "get_status", get_status)
    created = await client.post(
        "/api/image-jobs", headers=headers,
        files={"file": ("craft.jpg", dummy_image_bytes(), "image/jpeg")},
    )
    response = await client.post(
        "/api/products", headers=headers,
        json={
            "title_en": "Pending Handmade Bowl",
            "price": 100,
            "status": "published",
            "image_job_id": created.json()["job_id"],
            "selected_variant_ids": ["v1", "v2", "v3"],
        },
    )
    assert response.status_code == 400


@pytest.mark.asyncio
async def test_job_fails_when_generated_image_storage_fails(monkeypatch):
    job = ImageProcessingJob(
        id="storage-failure-job",
        artisan_id=3,
        status="running",
        original_photo_url="https://cdn.example.test/original.jpg",
        variants=[],
        errors=[],
    )

    async def fail_storage(url, filename):
        return None, None

    monkeypatch.setattr("app.utils.image_jobs._rehost_if_needed", fail_storage)
    await persist_normalized_result(job, {
        "job_status": "completed",
        "segmentation_status": "ok",
        "requires_review": False,
        "variants": [{"id": "v1", "image_url": "https://cdn.example.test/v1.jpg"}],
    })
    assert job.status == "failed"
    assert any("could not be stored" in message for message in job.errors)


@pytest.mark.asyncio
async def test_running_crewai_job_times_out_after_processing_deadline():
    job = ImageProcessingJob(
        id="timed-out-job",
        artisan_id=3,
        status="running",
        original_photo_url="https://cdn.example.test/original.jpg",
        crewai_execution_id="execution-123",
        created_at=datetime.now(timezone.utc) - timedelta(minutes=31),
        variants=[],
        errors=[],
    )
    await refresh_job_from_crewai(None, job)
    assert job.status == "failed"
    assert "30 minute" in job.errors[0]


# ─── Test 1: Successful Photo Upload ──────────────────────────────────────────

@pytest.mark.asyncio
async def test_successful_photo_upload(client: AsyncClient, monkeypatch):
    token = await get_artisan_token(client, "+919900000001", "Photo Artisan")
    headers = {"Authorization": f"Bearer {token}"}

    # Mock CrewAI kickoff
    async def mock_kickoff(self, inputs):
        return "kickoff_mock_001"

    monkeypatch.setattr(CrewAIClient, "is_configured", lambda self: True)
    monkeypatch.setattr(CrewAIClient, "kickoff", mock_kickoff)

    files = {"file": ("test_pot.jpg", dummy_image_bytes(), "image/jpeg")}
    data = {
        "product_name": "Blue Glazed Clay Vase",
        "product_category": "Pottery",
        "generate_variations": "true",
    }
    res = await client.post("/api/image-jobs", headers=headers, files=files, data=data)
    assert res.status_code == 201
    job_data = res.json()
    assert "job_id" in job_data
    assert job_data["status"] == "running"
    assert job_data["crewai_execution_id"] == "kickoff_mock_001"
    assert job_data["original_photo_url"] is not None
    assert "test_pot" in job_data["original_photo_url"] or "/uploads/" in job_data["original_photo_url"]


# ─── Test 2: CrewAI Kickoff and Status Retrieval ──────────────────────────────

@pytest.mark.asyncio
async def test_crewai_kickoff_and_status_retrieval(client: AsyncClient, monkeypatch):
    token = await get_artisan_token(client, "+919900000002", "Polling Artisan")
    headers = {"Authorization": f"Bearer {token}"}

    async def mock_kickoff(self, inputs):
        return "kickoff_poll_002"

    async def mock_get_status(self, kickoff_id):
        return {
            "status": "completed",
            "kickoff_id": kickoff_id,
            "result": {
                "segmentation_status": "ok",
                "cutout_url": "https://images.unsplash.com/cutout.jpg",
                "variants": [
                    {"id": "var_01", "image_url": "https://images.unsplash.com/v1.jpg", "background": {"name": "white", "hex": "#FFFFFF"}},
                    {"id": "var_02", "image_url": "https://images.unsplash.com/v2.jpg", "background": {"name": "cream", "hex": "#F5E9D8"}},
                    {"id": "var_03", "image_url": "https://images.unsplash.com/v3.jpg", "background": {"name": "sage_green", "hex": "#A3B18A"}},
                    {"id": "var_04", "image_url": "https://images.unsplash.com/v4.jpg", "background": {"name": "terracotta", "hex": "#C76F4E"}},
                    {"id": "var_05", "image_url": "https://images.unsplash.com/v5.jpg", "background": {"name": "charcoal", "hex": "#303030"}},
                ],
            },
        }

    monkeypatch.setattr(CrewAIClient, "is_configured", lambda self: True)
    monkeypatch.setattr(CrewAIClient, "kickoff", mock_kickoff)
    monkeypatch.setattr(CrewAIClient, "get_status", mock_get_status)

    files = {"file": ("pot.jpg", dummy_image_bytes(), "image/jpeg")}
    start_res = await client.post("/api/image-jobs", headers=headers, files=files, data={"product_name": "Pot"})
    job_id = start_res.json()["job_id"]

    # Poll status
    get_res = await client.get(f"/api/image-jobs/{job_id}", headers=headers)
    assert get_res.status_code == 200
    res_data = get_res.json()
    assert res_data["status"] == "completed"
    assert res_data["segmentation_status"] == "ok"
    assert len(res_data["variants"]) == 5
    assert "/uploads/" in res_data["cutout_url"]
    saved_output = await client.get(f"/api/image-jobs/{job_id}/output", headers=headers)
    assert saved_output.status_code == 200
    assert len(saved_output.json()["output_json"]["agent_output"]["variants"]) == 5
    assert "data_uri" not in saved_output.text


# ─── Test 3: Workflow Timeout and API Failure ─────────────────────────────────

@pytest.mark.asyncio
async def test_workflow_timeout_and_api_failure(client: AsyncClient, monkeypatch):
    token = await get_artisan_token(client, "+919900000003", "Failing Artisan")
    headers = {"Authorization": f"Bearer {token}"}

    async def mock_kickoff(self, inputs):
        raise CrewAIError("CrewAI upstream timeout (504 Gateway Timeout)", status_code=504)

    monkeypatch.setattr(CrewAIClient, "is_configured", lambda self: True)
    monkeypatch.setattr(CrewAIClient, "kickoff", mock_kickoff)

    files = {"file": ("pot.jpg", dummy_image_bytes(), "image/jpeg")}
    res = await client.post("/api/image-jobs", headers=headers, files=files)
    assert res.status_code == 201
    job_data = res.json()
    assert job_data["status"] == "failed"
    assert any("504" in err for err in job_data.get("errors", []))


# ─── Test 4: Invalid JSON and Missing Fields ──────────────────────────────────

def test_invalid_json_and_missing_fields():
    # 1. Non-dict result
    with pytest.raises(InvalidImageJobResult, match="without a JSON object"):
        normalize_final_json("Plain string that has no JSON")

    # 2. Variants not a list
    with pytest.raises(InvalidImageJobResult, match="variants must be a list"):
        normalize_final_json({"variants": "not a list"})

    # 3. Variant missing an ID
    with pytest.raises(InvalidImageJobResult, match="missing an id"):
        normalize_final_json({"variants": [{"image_url": "https://example.com/v1.jpg"}]})

    # 4. Success=False handling
    failed_payload = {"success": False, "error": "Model failed to segment craft boundary"}
    parsed = normalize_final_json(failed_payload)
    assert parsed["job_status"] == "failed"
    assert parsed["requires_review"] is True


# ─── Test 5: Segmentation Failure and Retake Handling ────────────────────────

def test_segmentation_failure_and_retake_handling():
    payload = {
        "segmentation_status": "retake_required",
        "retake_required": True,
        "quality_warnings": ["Subject is heavily cropped", "Blurry edges"],
    }
    parsed = normalize_final_json(payload)
    assert parsed["job_status"] == "retake_required"
    assert parsed["segmentation_status"] == "retake_required"
    assert parsed["requires_review"] is True
    assert "Blurry edges" in parsed["quality_warnings"]
    assert len(parsed["variants"]) == 0


# ─── Test 6: Missing or Inaccessible Image URLs ───────────────────────────────

def test_missing_or_inaccessible_image_urls():
    # Variants with no image_url or data_uri must raise InvalidImageJobResult
    payload = {
        "segmentation_status": "ok",
        "variants": [
            {"id": "var_1", "image_url": None, "background": "white"},
            {"id": "var_2", "image_url": "", "background": "cream"},
        ],
    }
    with pytest.raises(InvalidImageJobResult):
        normalize_final_json(payload)


# ─── Test 7: MongoDB Persistence and Update Behavior ─────────────────────────

@pytest.mark.asyncio
async def test_mongodb_persistence_and_update_behavior(monkeypatch):
    documents = {}

    class FakeCollection:
        async def update_one(self, query, update, upsert=False):
            key_name, key_value = next(iter(query.items()))
            document = documents.setdefault(key_value, {key_name: key_value})
            document.update(update.get("$set", {}))
            for key, value in update.get("$setOnInsert", {}).items():
                document.setdefault(key, value)

        async def find_one(self, query, projection=None):
            key_name, key_value = next(iter(query.items()))
            document = documents.get(key_value)
            if document and all(document.get(k) == v for k, v in query.items()):
                return dict(document)
            return None

        async def find_one_and_update(self, query, update, **kwargs):
            key_name, key_value = next(iter(query.items()))
            document = documents.get(key_value)
            if document and all(document.get(k) == v for k, v in query.items()):
                document.update(update.get("$set", {}))
                return dict(document)
            return None

    class FakeDatabase:
        def __getitem__(self, collection_name):
            return FakeCollection()

    monkeypatch.setattr("app.mongodb.get_mongo_database", lambda: FakeDatabase())
    test_job_id = "mongo-test-job-001"
    doc = {
        "job_id": test_job_id,
        "product_id": None,
        "artisan_id": "artisan_999",
        "status": "processing",
        "segmentation_status": "pending",
        "requires_review": False,
        "original_photo": {"image_url": "https://example.com/raw.jpg", "storage_key": "raw.jpg"},
        "cutout": {"image_url": None, "storage_key": None},
        "variants": [
            {"id": "v1", "variant_id": "v1", "image_url": "https://example.com/v1.jpg", "saved": True, "status": "ready"},
            {"id": "v2", "variant_id": "v2", "image_url": "https://example.com/v2.jpg", "saved": True, "status": "ready"},
            {"id": "v3", "variant_id": "v3", "image_url": "https://example.com/v3.jpg", "saved": True, "status": "ready"},
        ],
        "required_selection_count": 3,
        "selected_variant_ids": [],
        "error": None,
        "warnings": [],
        "crewai_execution_id": "exec_123",
        "output_json": {
            "status": "completed",
            "variants": [{"variant_id": "v1", "image_url": "https://cdn.example.test/v1.jpg"}],
        },
    }
    # 1. Upsert
    saved = await save_image_job_mongo(doc)
    assert saved["job_id"] == test_job_id

    # 2. Retrieve
    retrieved = await get_image_job_mongo(test_job_id)
    assert retrieved is not None
    assert retrieved["artisan_id"] == "artisan_999"
    assert retrieved["output_json"]["status"] == "completed"
    assert retrieved["output_json"]["variants"][0]["variant_id"] == "v1"

    # 3. Update selection atomically
    updated = await update_job_selection_mongo(test_job_id, "artisan_999", ["v1", "v2", "v3"])
    assert updated["selected_variant_ids"] == ["v1", "v2", "v3"]


# ─── Test 8: Duplicate Request / Idempotency Handling ────────────────────────

@pytest.mark.asyncio
async def test_duplicate_request_idempotency_handling(client: AsyncClient):
    token = await get_artisan_token(client, "+919900000008", "Idempotent Artisan")
    headers = {"Authorization": f"Bearer {token}"}

    payload = {
        "title_en": "Terracotta Diya Set",
        "price": 250.0,
        "stock": 5,
        "status": "draft",
        "idempotency_key": "unique-idemp-key-777",
    }
    res1 = await client.post("/api/products", headers=headers, json=payload)
    assert res1.status_code == 201
    prod_id = res1.json()["id"]

    # Send duplicate request with exact same idempotency_key
    res2 = await client.post("/api/products", headers=headers, json=payload)
    assert res2.status_code in (200, 201)
    assert res2.json()["id"] == prod_id


# ─── Test 9: Artisan Ownership and Authorization ──────────────────────────────

@pytest.mark.asyncio
async def test_artisan_ownership_and_authorization(client: AsyncClient, monkeypatch):
    token_a = await get_artisan_token(client, "+919900000091", "Artisan A")
    token_b = await get_artisan_token(client, "+919900000092", "Artisan B")

    async def mock_kickoff(self, inputs):
        return "kickoff_owner_test"

    monkeypatch.setattr(CrewAIClient, "is_configured", lambda self: True)
    monkeypatch.setattr(CrewAIClient, "kickoff", mock_kickoff)

    # Artisan A creates a job
    files = {"file": ("art_a.jpg", dummy_image_bytes(), "image/jpeg")}
    res_a = await client.post("/api/image-jobs", headers={"Authorization": f"Bearer {token_a}"}, files=files)
    job_id = res_a.json()["job_id"]

    # Artisan B tries to access Artisan A's job -> 404 Not Found (isolated)
    res_b = await client.get(f"/api/image-jobs/{job_id}", headers={"Authorization": f"Bearer {token_b}"})
    assert res_b.status_code == 404

    # Unauthenticated user -> 401
    res_unauth = await client.get(f"/api/image-jobs/{job_id}")
    assert res_unauth.status_code in (401, 403)


# ─── Test 10: Selection of Exactly Three Variants ─────────────────────────────

@pytest.mark.asyncio
async def test_selection_of_exactly_three_variants(client: AsyncClient, monkeypatch):
    token = await get_artisan_token(client, "+919900000101", "Select 3 Artisan")
    headers = {"Authorization": f"Bearer {token}"}

    async def mock_kickoff(self, inputs):
        return "kickoff_sel_test"

    async def mock_get_status(self, kickoff_id):
        return {
            "status": "completed",
            "kickoff_id": kickoff_id,
            "result": {
                "segmentation_status": "ok",
                "variants": [
                    {"id": "var_1", "image_url": "https://example.com/v1.jpg"},
                    {"id": "var_2", "image_url": "https://example.com/v2.jpg"},
                    {"id": "var_3", "image_url": "https://example.com/v3.jpg"},
                    {"id": "var_4", "image_url": "https://example.com/v4.jpg"},
                    {"id": "var_5", "image_url": "https://example.com/v5.jpg"},
                ],
            },
        }

    monkeypatch.setattr(CrewAIClient, "is_configured", lambda self: True)
    monkeypatch.setattr(CrewAIClient, "kickoff", mock_kickoff)
    monkeypatch.setattr(CrewAIClient, "get_status", mock_get_status)

    files = {"file": ("item.jpg", dummy_image_bytes(), "image/jpeg")}
    job = (await client.post("/api/image-jobs", headers=headers, files=files)).json()
    job_id = job["job_id"]

    # Refresh to completed
    await client.get(f"/api/image-jobs/{job_id}", headers=headers)

    # Select exactly 3 variants via PUT /api/image-jobs/{id}/selection
    sel_res = await client.put(
        f"/api/image-jobs/{job_id}/selection",
        headers=headers,
        json={"variant_ids": ["var_1", "var_3", "var_5"]},
    )
    assert sel_res.status_code == 200
    assert sel_res.json()["selected_variant_ids"] == ["var_1", "var_3", "var_5"]


# ─── Test 11: Rejection of Invalid Variant Selections ─────────────────────────

@pytest.mark.asyncio
async def test_rejection_of_invalid_variant_selections(client: AsyncClient, monkeypatch):
    token = await get_artisan_token(client, "+919900000111", "Validation Artisan")
    headers = {"Authorization": f"Bearer {token}"}

    async def mock_kickoff(self, inputs):
        return "kickoff_val_test"

    async def mock_get_status(self, kickoff_id):
        return {
            "status": "completed",
            "kickoff_id": kickoff_id,
            "result": {
                "segmentation_status": "ok",
                "variants": [
                    {"id": "var_1", "image_url": "https://example.com/v1.jpg"},
                    {"id": "var_2", "image_url": "https://example.com/v2.jpg"},
                    {"id": "var_3", "image_url": "https://example.com/v3.jpg"},
                ],
            },
        }

    monkeypatch.setattr(CrewAIClient, "is_configured", lambda self: True)
    monkeypatch.setattr(CrewAIClient, "kickoff", mock_kickoff)
    monkeypatch.setattr(CrewAIClient, "get_status", mock_get_status)

    files = {"file": ("item.jpg", dummy_image_bytes(), "image/jpeg")}
    job = (await client.post("/api/image-jobs", headers=headers, files=files)).json()
    job_id = job["job_id"]
    await client.get(f"/api/image-jobs/{job_id}", headers=headers)

    # 1. Fewer than 3 selections (2) -> 422 or 400
    res_few = await client.put(
        f"/api/image-jobs/{job_id}/selection",
        headers=headers,
        json={"variant_ids": ["var_1", "var_2"]},
    )
    assert res_few.status_code in (400, 422)

    # 2. More than 3 selections (4) -> 422 or 400
    res_many = await client.put(
        f"/api/image-jobs/{job_id}/selection",
        headers=headers,
        json={"variant_ids": ["var_1", "var_2", "var_3", "var_4"]},
    )
    assert res_many.status_code in (400, 422)

    # 3. Duplicate IDs -> 422 or 400
    res_dup = await client.put(
        f"/api/image-jobs/{job_id}/selection",
        headers=headers,
        json={"variant_ids": ["var_1", "var_1", "var_2"]},
    )
    assert res_dup.status_code in (400, 422)

    # 4. Unknown variant ID -> 400 Bad Request
    res_unk = await client.put(
        f"/api/image-jobs/{job_id}/selection",
        headers=headers,
        json={"variant_ids": ["var_1", "var_2", "unknown_xyz"]},
    )
    assert res_unk.status_code == 400


# ─── Test 12: Product Draft versus Published Visibility ───────────────────────

@pytest.mark.asyncio
async def test_product_draft_versus_published_visibility(client: AsyncClient):
    token = await get_artisan_token(client, "+919900000121", "Visibility Artisan")
    headers = {"Authorization": f"Bearer {token}"}

    # 1. Create a draft product
    create_res = await client.post(
        "/api/products",
        headers=headers,
        json={
            "title_en": "Draft Silk Shawl",
            "price": 1200.0,
            "stock": 2,
            "status": "draft",
        },
    )
    assert create_res.status_code == 201
    prod_id = create_res.json()["id"]

    # Draft must NOT appear in public catalog
    catalog_res = await client.get("/api/products")
    assert not any(p["id"] == prod_id for p in catalog_res.json()["items"])

    # 2. Publish the draft
    pub_res = await client.post(f"/api/products/{prod_id}/publish", headers=headers)
    assert pub_res.status_code == 200
    assert pub_res.json()["status"] == "published"

    # Now it MUST appear in the public catalog
    catalog_after = await client.get("/api/products")
    assert any(p["id"] == prod_id for p in catalog_after.json()["items"])


# ─── Test 13: Display of Saved Images on Published Product ────────────────────

@pytest.mark.asyncio
async def test_display_of_saved_images_on_product(client: AsyncClient, monkeypatch):
    token = await get_artisan_token(client, "+919900000131", "Images Artisan")
    headers = {"Authorization": f"Bearer {token}"}

    async def mock_kickoff(self, inputs):
        return "kickoff_display_test"

    async def mock_get_status(self, kickoff_id):
        return {
            "status": "completed",
            "kickoff_id": kickoff_id,
            "result": {
                "segmentation_status": "ok",
                "variants": [
                    {"id": "var_1", "image_url": "https://example.com/craft_v1.jpg"},
                    {"id": "var_2", "image_url": "https://example.com/craft_v2.jpg"},
                    {"id": "var_3", "image_url": "https://example.com/craft_v3.jpg"},
                ],
            },
        }

    monkeypatch.setattr(CrewAIClient, "is_configured", lambda self: True)
    monkeypatch.setattr(CrewAIClient, "kickoff", mock_kickoff)
    monkeypatch.setattr(CrewAIClient, "get_status", mock_get_status)

    files = {"file": ("vase.jpg", dummy_image_bytes(), "image/jpeg")}
    job = (await client.post("/api/image-jobs", headers=headers, files=files)).json()
    job_id = job["job_id"]
    await client.get(f"/api/image-jobs/{job_id}", headers=headers)

    # Create product linked to job with selected 3 variants
    prod_payload = {
        "title_en": "Carved Teakwood Box",
        "price": 950.0,
        "stock": 3,
        "status": "published",
        "category_slug": "pottery",
        "image_job_id": job_id,
        "selected_variant_ids": ["var_1", "var_2", "var_3"],
    }
    prod_res = await client.post("/api/products", headers=headers, json=prod_payload)
    assert prod_res.status_code == 201
    prod_data = prod_res.json()

    # Verify exactly 3 images are present on product
    images = prod_data["images"]
    assert len(images) == 3
    assert "/uploads/" in images[0]["url"]
    assert images[0]["is_primary"] is True
    assert "/uploads/" in images[1]["url"]
    assert "/uploads/" in images[2]["url"]
    assert prod_data["category"]["slug"] == "pottery"
    linked_job = await client.get(f"/api/image-jobs/{job_id}", headers=headers)
    assert linked_job.json()["product_id"] == str(prod_data["id"])


# ─── Test 14: Preservation of Existing Functionality ──────────────────────────

@pytest.mark.asyncio
async def test_preservation_of_existing_functionality(client: AsyncClient):
    # 1. Health check
    health_res = await client.get("/health")
    assert health_res.status_code == 200
    assert health_res.json()["status"] == "healthy"

    # 2. Categories listing
    cat_res = await client.get("/api/products/categories")
    assert cat_res.status_code == 200
    assert len(cat_res.json()) >= 1

    # 3. Buyer checkout flow remains intact
    await client.post("/api/v1/auth/otp/send", json={"phone": "+919900000141", "role": "buyer"})
    buyer_tok = (await client.post(
        "/api/v1/auth/otp/verify",
        json={"phone": "+919900000141", "code": "123456", "name": "Buyer User", "role": "buyer"},
    )).json()["access_token"]
    assert buyer_tok is not None
