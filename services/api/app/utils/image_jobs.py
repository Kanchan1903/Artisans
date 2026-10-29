"""Create, poll, persist, and select CrewAI image-processing jobs."""
from __future__ import annotations

import base64
import json
import uuid
import httpx
import ipaddress
from urllib.parse import urlparse
from datetime import datetime, timezone
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models.image_job import ImageJobStatus, ImageProcessingJob
from app.mongodb import (
    get_image_job_mongo,
    list_artisan_jobs_mongo,
    save_image_job_mongo,
    update_job_selection_mongo,
)
from app.utils.crewai_client import CrewAIClient, CrewAIError, crewai_client
from app.utils.image_job_result import InvalidImageJobResult, parse_crewai_status_payload
from app.utils.storage import storage

DEFAULT_BACKGROUND_COLORS = [
    {"name": "white", "hex": "#FFFFFF", "type": "solid_color", "label": "Studio White"},
    {"name": "cream", "hex": "#F5E9D8", "type": "solid_color", "label": "Warm Cream"},
    {"name": "sage_green", "hex": "#A3B18A", "type": "solid_color", "label": "Sage Green"},
    {"name": "terracotta", "hex": "#C76F4E", "type": "solid_color", "label": "Terracotta"},
    {"name": "charcoal", "hex": "#303030", "type": "solid_color", "label": "Charcoal"},
]
image_output_transport_factory: Any = None


def storage_key_from_url(url: str | None) -> str | None:
    if not url:
        return None
    return url.rstrip("/").split("?")[0].split("/")[-1] or None


def job_to_mongo_dict(job: ImageProcessingJob) -> dict[str, Any]:
    variants = []
    for item in job.variants or []:
        if not isinstance(item, dict):
            continue
        vid = str(item.get("variant_id") or item.get("id") or "")
        variants.append(
            {
                "variant_id": vid,
                "id": vid,
                "background": item.get("background") or {},
                "image_url": item.get("image_url"),
                "storage_key": item.get("storage_key"),
                "saved": bool(item.get("image_url") and item.get("status") != "missing_image"),
                "status": item.get("status") or "ready_for_review",
            }
        )
    return {
        "job_id": str(job.id),
        "product_id": str(job.product_id) if job.product_id else None,
        "artisan_id": str(job.artisan_id),
        "status": job.status,
        "segmentation_status": job.segmentation_status or "pending",
        "requires_review": bool(job.requires_review),
        "original_photo": {
            "image_url": job.original_photo_url,
            "storage_key": job.original_storage_key,
        },
        "cutout": {
            "image_url": job.cutout_url,
            "storage_key": job.cutout_storage_key,
        },
        "variants": variants,
        "output_json": job.output_json,
        "required_selection_count": 3,
        "selected_variant_ids": job.selected_variant_ids or [],
        "error": job.errors[0] if (job.errors and len(job.errors) > 0) else None,
        "warnings": job.quality_warnings or [],
        "crewai_execution_id": job.crewai_execution_id,
        "created_at": job.created_at,
        "updated_at": job.updated_at,
    }


def job_to_dict(job: ImageProcessingJob) -> dict[str, Any]:
    m = job_to_mongo_dict(job)
    # Add root convenience keys
    m["original_photo_url"] = job.original_photo_url
    m["original_storage_key"] = job.original_storage_key
    m["cutout_url"] = job.cutout_url
    m["cutout_storage_key"] = job.cutout_storage_key
    m["product_name"] = job.product_name
    m["product_category"] = job.product_category
    m["errors"] = job.errors or []
    m["quality_warnings"] = job.quality_warnings or []
    m["processing_mode"] = "mock" if (job.crewai_execution_id or "").startswith("mock_") else "real"
    return m


async def _rehost_if_needed(value: str | None, filename: str) -> tuple[str | None, str | None]:
    """Copy agent output into configured storage; persist URLs/keys, never image bytes."""
    if not value:
        return None, None
    text = value.strip()
    if text.startswith("http://") or text.startswith("https://"):
        parsed_url = urlparse(text)
        host = (parsed_url.hostname or "").lower()
        try:
            local_host = host in {"localhost", "minio"} or host.endswith(".local") or ipaddress.ip_address(host).is_private
        except ValueError:
            local_host = host in {"localhost", "minio"} or host.endswith(".local")
        if parsed_url.scheme != "https" or not host or local_host or parsed_url.username or parsed_url.password:
            return None, None
        try:
            transport = image_output_transport_factory() if image_output_transport_factory else None
            async with httpx.AsyncClient(timeout=httpx.Timeout(30.0), follow_redirects=False, transport=transport) as client:
                async with client.stream("GET", text) as response:
                    response.raise_for_status()
                    content_type = response.headers.get("content-type", "").split(";", 1)[0].lower()
                    if content_type not in {"image/jpeg", "image/png", "image/webp", "image/gif"}:
                        return None, None
                    chunks = []
                    total_bytes = 0
                    async for chunk in response.aiter_bytes():
                        total_bytes += len(chunk)
                        if total_bytes > 15 * 1024 * 1024:
                            return None, None
                        chunks.append(chunk)
            raw = b"".join(chunks)
            from PIL import Image, UnidentifiedImageError
            import io
            try:
                with Image.open(io.BytesIO(raw)) as image:
                    if image.width * image.height > 40_000_000:
                        return None, None
                    image.verify()
            except (UnidentifiedImageError, OSError, ValueError, Image.DecompressionBombError):
                return None, None
            url = await storage.upload_file(raw, filename=filename, content_type=content_type)
            return url, storage_key_from_url(url)
        except Exception:
            return None, None
    if text.startswith("data:"):
        header, _, payload = text.partition(",")
        if not payload or len(payload) > 20 * 1024 * 1024:
            return None, None
        try:
            raw = base64.b64decode(payload)
        except Exception:
            return None, None
        content_type = "image/jpeg"
        if "image/png" in header:
            content_type = "image/png"
            filename = filename.rsplit(".", 1)[0] + ".png"
        elif "image/webp" in header:
            content_type = "image/webp"
            filename = filename.rsplit(".", 1)[0] + ".webp"
        elif "image/gif" in header:
            content_type = "image/gif"
            filename = filename.rsplit(".", 1)[0] + ".gif"
        elif "image/jpeg" not in header:
            return None, None
        if len(raw) > 15 * 1024 * 1024:
            return None, None
        try:
            from PIL import Image, UnidentifiedImageError
            import io
            with Image.open(io.BytesIO(raw)) as image:
                detected_type = Image.MIME.get(image.format)
                if image.width * image.height > 40_000_000:
                    return None, None
                image.verify()
            if detected_type != content_type:
                return None, None
            url = await storage.upload_file(raw, filename=filename, content_type=content_type)
            return url, storage_key_from_url(url)
        except Exception:
            return None, None
    return None, None


async def persist_normalized_result(job: ImageProcessingJob, parsed: dict[str, Any]) -> None:
    job.status = parsed.get("job_status") or job.status
    job.segmentation_status = parsed.get("segmentation_status") or job.segmentation_status
    job.requires_review = bool(parsed.get("requires_review"))
    if job.status == ImageJobStatus.completed.value and job.requires_review:
        job.status = "awaiting_review"
    job.quality_warnings = parsed.get("quality_warnings") or []
    job.errors = parsed.get("errors") or []
    if parsed.get("crewai_execution_id"):
        job.crewai_execution_id = str(parsed["crewai_execution_id"])

    cutout_url, cutout_key = await _rehost_if_needed(
        parsed.get("cutout_url"), f"cutout-{job.id}.jpg"
    )
    if cutout_url:
        job.cutout_url = cutout_url
        job.cutout_storage_key = parsed.get("cutout_storage_key") or cutout_key

    stored_variants: list[dict[str, Any]] = []
    for item in parsed.get("variants") or []:
        source = item.get("image_url") or item.get("data_uri")
        url, key = await _rehost_if_needed(source, f"variant-{job.id}-{item.get('id')}.jpg")
        vid = str(item.get("variant_id") or item.get("id"))
        stored_variants.append(
            {
                "id": vid,
                "variant_id": vid,
                "background": item.get("background") or {},
                "image_url": url,
                "storage_key": item.get("storage_key") or key,
                "saved": bool(url),
                "status": "missing_image" if not url else item.get("status") or "ready_for_review",
            }
        )
    if stored_variants:
        job.variants = stored_variants

    if parsed.get("job_status") == "completed":
        valid = [v for v in stored_variants if v.get("image_url") and v.get("status") != "missing_image"]
        if len(valid) != len(parsed.get("variants") or []):
            job.status = ImageJobStatus.failed.value
            job.errors = list(job.errors or []) + ["One or more generated images could not be stored"]
            job.requires_review = True
        elif not valid:
            job.status = ImageJobStatus.failed.value
            job.errors = list(job.errors or []) + ["Completed result contained no usable image URLs"]
            job.requires_review = True

    job.output_json = {
        "job_id": str(job.id),
        "product_id": str(job.product_id) if job.product_id else None,
        "artisan_id": str(job.artisan_id),
        "crewai_execution_id": job.crewai_execution_id,
        "status": job.status,
        "segmentation_status": job.segmentation_status,
        "requires_review": job.requires_review,
        "original_photo": {
            "image_url": job.original_photo_url,
            "storage_key": job.original_storage_key,
        },
        "cutout": {"image_url": job.cutout_url, "storage_key": job.cutout_storage_key},
        "variants": stored_variants,
        "selected_variant_ids": job.selected_variant_ids or [],
        "quality_warnings": job.quality_warnings or [],
        "errors": job.errors or [],
        "updated_at": datetime.now(timezone.utc).isoformat(),
        "agent_output": {
            "job_status": parsed.get("job_status"),
            "segmentation_status": job.segmentation_status,
            "requires_review": job.requires_review,
            "cutout_url": job.cutout_url,
            "cutout_storage_key": job.cutout_storage_key,
            "variants": stored_variants,
            "selected_variant_ids": job.selected_variant_ids or [],
            "quality_warnings": job.quality_warnings or [],
            "errors": job.errors or [],
        },
    }

    # Persist queryable result JSON to MongoDB before reporting successful processing.
    try:
        await save_image_job_mongo(job_to_mongo_dict(job))
    except Exception:
        if settings.MONGODB_REQUIRED:
            job.status = ImageJobStatus.failed.value
            job.requires_review = True
            job.errors = list(job.errors or []) + ["The processing output could not be saved to MongoDB"]
            job.output_json["status"] = job.status
            job.output_json["requires_review"] = True
            job.output_json["errors"] = job.errors
            job.output_json["agent_output"]["job_status"] = job.status
            job.output_json["agent_output"]["requires_review"] = True
            job.output_json["agent_output"]["errors"] = job.errors


async def build_kickoff_inputs(
    job: ImageProcessingJob,
    generate_variations: bool = True,
    client: CrewAIClient | None = None,
) -> dict[str, str]:
    client = client or crewai_client
    colors = json.dumps(DEFAULT_BACKGROUND_COLORS)
    inputs = {
        "job_id": job.id,
        "artisan_id": str(job.artisan_id),
        "photo_url": job.original_photo_url,
        "product_name": job.product_name or "Handmade product",
        "product_category": job.product_category or "uncategorized",
        "background_colors": colors,
        "generate_variations": "true" if generate_variations else "false",
        "product_id": str(job.product_id or ""),
    }
    try:
        discovered = await client.get_inputs()
        if discovered:
            allowed = set(discovered)
            filtered = {k: v for k, v in inputs.items() if k in allowed}
            return filtered
    except CrewAIError:
        pass
    return inputs


async def create_and_kickoff_job(
    db: AsyncSession,
    *,
    artisan_id: int,
    file_bytes: bytes,
    filename: str,
    content_type: str,
    product_name: str | None,
    product_category: str | None,
    product_id: int | None,
    generate_variations: bool = True,
    client: CrewAIClient | None = None,
) -> ImageProcessingJob:
    client = client or crewai_client
    job_id = str(uuid.uuid4())
    photo_url = await storage.upload_file(file_bytes, filename=filename, content_type=content_type)
    now = datetime.now(timezone.utc)
    job = ImageProcessingJob(
        id=job_id,
        artisan_id=artisan_id,
        product_id=product_id,
        product_name=product_name,
        product_category=product_category,
        status=ImageJobStatus.queued.value,
        segmentation_status="pending",
        original_photo_url=photo_url,
        original_storage_key=storage_key_from_url(photo_url),
        variants=[],
        quality_warnings=[],
        errors=[],
        selected_variant_ids=[],
        created_at=now,
        updated_at=now,
    )
    db.add(job)
    await db.flush()

    # Save initial job to MongoDB
    try:
        await save_image_job_mongo(job_to_mongo_dict(job))
    except Exception:
        if settings.MONGODB_REQUIRED:
            job.status = ImageJobStatus.failed.value
            job.errors = ["MongoDB is unavailable; the image job could not be recorded"]
            return job

    if not client.is_configured():
        # Mock mode is observable but never pretends that image processing succeeded.
        from app.config import settings as _settings
        if _settings.AI_MOCK_MODE:
            job = _apply_mock_result(job)
        else:
            job.status = ImageJobStatus.failed.value
            job.errors = ["CrewAI is not configured. Set CREWAI_BEARER_TOKEN on the backend."]
        try:
            await save_image_job_mongo(job_to_mongo_dict(job))
        except Exception:
            if settings.MONGODB_REQUIRED:
                job.status = ImageJobStatus.failed.value
                job.errors = ["The mock job result could not be saved to MongoDB"]
        return job

    host = (urlparse(photo_url).hostname or "").lower()
    try:
        local_host = host in {"localhost", "minio"} or host.endswith(".local") or ipaddress.ip_address(host).is_private
    except ValueError:
        local_host = host in {"localhost", "minio"} or host.endswith(".local")
    if not photo_url.startswith("https://") or local_host:
        job.status = ImageJobStatus.failed.value
        job.errors = ["CrewAI cannot reach the uploaded photo. Configure a public HTTPS MINIO_PUBLIC_URL or PUBLIC_API_URL."]
        try:
            await save_image_job_mongo(job_to_mongo_dict(job))
        except Exception:
            pass
        return job

    try:
        inputs = await build_kickoff_inputs(job, generate_variations=generate_variations, client=client)
        kickoff_id = await client.kickoff(inputs)
        job.crewai_execution_id = kickoff_id
        job.status = ImageJobStatus.running.value
    except CrewAIError as exc:
        job.status = ImageJobStatus.failed.value
        job.errors = [str(exc)]

    # Update MongoDB after kickoff
    try:
        await save_image_job_mongo(job_to_mongo_dict(job))
    except Exception:
        pass
    return job


def _apply_mock_result(job: ImageProcessingJob) -> ImageProcessingJob:
    """Expose mock mode as non-publishable; never fabricate processing results."""
    job.status = "awaiting_review"
    job.segmentation_status = "mock"
    job.requires_review = True
    job.variants = []
    job.quality_warnings = ["AI_MOCK_MODE is enabled; no image processing was performed."]
    job.errors = []
    job.cutout_url = None
    job.crewai_execution_id = f"mock_{uuid.uuid4().hex[:12]}"
    job.output_json = {
        "job_id": str(job.id),
        "product_id": str(job.product_id) if job.product_id else None,
        "artisan_id": str(job.artisan_id),
        "processing_mode": "mock",
        "processed": False,
        "status": job.status,
        "requires_review": True,
        "quality_warnings": job.quality_warnings,
        "variants": [],
    }
    job.updated_at = datetime.now(timezone.utc)
    return job


async def refresh_job_from_crewai(
    db: AsyncSession,
    job: ImageProcessingJob,
    client: CrewAIClient | None = None,
) -> ImageProcessingJob:
    if job.status in (
        ImageJobStatus.completed.value,
        ImageJobStatus.failed.value,
        ImageJobStatus.retake_required.value,
        "awaiting_review",
    ):
        return job
    if not job.crewai_execution_id:
        return job

    created = job.created_at
    if created is not None:
        if created.tzinfo is None:
            created = created.replace(tzinfo=timezone.utc)
        if (datetime.now(timezone.utc) - created).total_seconds() > 1800:
            job.status = ImageJobStatus.failed.value
            job.requires_review = True
            job.errors = ["CrewAI image processing exceeded the 30 minute time limit"]
            job.updated_at = datetime.now(timezone.utc)
            try:
                await save_image_job_mongo(job_to_mongo_dict(job))
            except Exception:
                pass
            return job

    client = client or crewai_client
    try:
        payload = await client.get_status(job.crewai_execution_id)
    except CrewAIError as exc:
        job.errors = list(job.errors or []) + [str(exc)]
        job.updated_at = datetime.now(timezone.utc)
        try:
            await save_image_job_mongo(job_to_mongo_dict(job))
        except Exception:
            pass
        return job

    status = str(payload.get("status") or "").lower()
    if status in ("running", "started", "pending", "queued", "in_progress"):
        job.status = ImageJobStatus.running.value
        return job

    try:
        parsed = parse_crewai_status_payload(payload)
    except InvalidImageJobResult as exc:
        job.status = ImageJobStatus.failed.value
        job.errors = [str(exc)]
        job.requires_review = True
        try:
            await save_image_job_mongo(job_to_mongo_dict(job))
        except Exception:
            pass
        return job

    await persist_normalized_result(job, parsed)
    job.updated_at = datetime.now(timezone.utc)
    return job


async def get_job_for_artisan(db: AsyncSession, job_id: str, artisan_id: int) -> ImageProcessingJob | None:
    stmt = select(ImageProcessingJob).where(
        ImageProcessingJob.id == job_id,
        ImageProcessingJob.artisan_id == artisan_id,
    )
    result = await db.execute(stmt)
    return result.scalar_one_or_none()


def selectable_variant_ids(job: ImageProcessingJob) -> set[str]:
    ids: set[str] = set()
    for item in job.variants or []:
        if not isinstance(item, dict):
            continue
        vid = str(item.get("variant_id") or item.get("id") or "")
        if item.get("image_url") and vid and item.get("status") != "missing_image":
            ids.add(vid)
            if item.get("id"):
                ids.add(str(item["id"]))
            if item.get("variant_id"):
                ids.add(str(item["variant_id"]))
    return ids


async def apply_variant_selection(job: ImageProcessingJob, variant_ids: list[str]) -> None:
    if job.status != ImageJobStatus.completed.value:
        raise ValueError("Variants can only be selected after processing completes")
    if job.segmentation_status == ImageJobStatus.retake_required.value or job.requires_review:
        raise ValueError("This result requires human review or a retake before variants can be selected")

    unique = list(dict.fromkeys(variant_ids))
    if len(variant_ids) != 3 or len(unique) != 3:
        raise ValueError("Select exactly three distinct variants")

    allowed = selectable_variant_ids(job)
    unknown = [vid for vid in unique if vid not in allowed]
    if unknown:
        raise ValueError("Unknown or unusable variant IDs for this job")

    job.selected_variant_ids = unique
    job.updated_at = datetime.now(timezone.utc)
    if job.output_json is not None:
        job.output_json = {**job.output_json, "selected_variant_ids": unique}

    # Persist selection to MongoDB
    try:
        await update_job_selection_mongo(job.id, job.artisan_id, unique)
    except Exception:
        pass


def selected_variant_records(job: ImageProcessingJob) -> list[dict[str, Any]]:
    selected = job.selected_variant_ids or []
    by_id: dict[str, dict[str, Any]] = {}
    for v in (job.variants or []):
        if not isinstance(v, dict):
            continue
        if v.get("id"):
            by_id[str(v["id"])] = v
        if v.get("variant_id"):
            by_id[str(v["variant_id"])] = v

    records = []
    for vid in selected:
        item = by_id.get(str(vid))
        if item and item.get("image_url"):
            records.append(item)
    return records
