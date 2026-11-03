"""Artisan image-processing jobs backed by the deployed CrewAI workflow and MongoDB."""
from __future__ import annotations

from fastapi import APIRouter, BackgroundTasks, Depends, File, Form, HTTPException, UploadFile, status
import json
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_current_artisan
from app.database import AsyncSessionLocal, get_db
from app.models.artisan import ArtisanProfile
from app.models.image_job import ImageProcessingJob
from app.models.user import User
from app.models.product import Product
from app.mongodb import get_image_job_mongo, list_artisan_jobs_mongo
from app.mongodb import save_image_job_mongo
from app.schemas.image_job import ImageJobOut, SelectVariantsIn, ReviewImageJobIn
from app.utils.image_jobs import (
    apply_variant_selection,
    create_and_kickoff_job,
    get_job_for_artisan,
    job_to_dict,
    job_to_mongo_dict,
    refresh_job_from_crewai,
    retry_existing_job,
)
from app.utils.product_image_processing import prepare_product_image

router = APIRouter(prefix="/image-jobs", tags=["AI Image Jobs"])
MAX_IMAGE_BYTES = 15 * 1024 * 1024
SUPPORTED_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp"}


def _to_out(job: ImageProcessingJob) -> ImageJobOut:
    data = job_to_dict(job)
    return ImageJobOut(**data)


async def _background_refresh(job_id: str, artisan_id: int) -> None:
    async with AsyncSessionLocal() as db:
        try:
            job = await get_job_for_artisan(db, job_id, artisan_id)
            if not job:
                return
            await refresh_job_from_crewai(db, job)
            await db.commit()
        except Exception:
            await db.rollback()


@router.post("", response_model=ImageJobOut, status_code=status.HTTP_201_CREATED)
async def start_image_job(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    product_name: str = Form(""),
    product_category: str = Form(""),
    product_id: int | None = Form(None),
    upload_id: str | None = Form(None),
    generate_variations: bool = Form(True),
    artisan_tuple: tuple[User, ArtisanProfile] = Depends(get_current_artisan),
    db: AsyncSession = Depends(get_db),
):
    """Validate and store the original, create its job, and start the backend CrewAI workflow."""
    user, profile = artisan_tuple
    if upload_id is not None and (not upload_id.strip() or len(upload_id) > 100):
        raise HTTPException(status_code=400, detail="Invalid upload ID")
    if file.content_type not in SUPPORTED_IMAGE_TYPES:
        raise HTTPException(status_code=415, detail="Upload a JPEG, PNG, or WebP image")
    file_bytes = await file.read(MAX_IMAGE_BYTES + 1)
    if len(file_bytes) > MAX_IMAGE_BYTES:
        raise HTTPException(status_code=413, detail="Image exceeds the 15 MB upload limit")
    if not file_bytes:
        raise HTTPException(status_code=400, detail="Uploaded file is empty")
    try:
        processing_bytes, processing_type, extension = prepare_product_image(
            file_bytes, file.content_type or ""
        )
    except ValueError as exc:
        raise HTTPException(status_code=415, detail=str(exc)) from exc
    if product_id is not None:
        product_result = await db.execute(select(Product).where(
            Product.id == product_id, Product.artisan_id == profile.id
        ))
        product = product_result.scalar_one_or_none()
        if product is None:
            raise HTTPException(status_code=404, detail="Product not found for this artisan")
        if product.status.value != "draft":
            raise HTTPException(status_code=409, detail="AI processing can only run for a draft product")

    product_context = {}
    if product_id is not None:
        product_context = {
            "product_description": product.description_en or "",
            "material": product.material or "",
            "dimensions": product.dimensions or "",
            "weight_grams": str(product.weight_grams) if product.weight_grams is not None else "",
            "price": str(product.price),
            "quantity": str(product.stock),
            "additional_details": json.dumps(product.additional_details or {}, ensure_ascii=False),
        }

    try:
        job = await create_and_kickoff_job(
            db,
            artisan_id=profile.id,
            file_bytes=processing_bytes,
            filename=f"{(file.filename or 'craft').rsplit('.', 1)[0]}.{extension.lstrip('.')}",
            content_type=processing_type,
            product_name=product_name or None,
            product_category=product_category or None,
            product_id=product_id,
            idempotency_key=upload_id.strip() if upload_id else None,
            generate_variations=generate_variations,
            product_context=product_context,
        )
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail="Image storage is temporarily unavailable") from exc
    if job.crewai_execution_id:
        background_tasks.add_task(_background_refresh, job.id, profile.id)
    if product_id is not None:
        product = await db.get(Product, product_id)
        if product is not None:
            product.processing_status = "processing" if job.status in {"queued", "running"} else "failed"
            product.ai_processing_result = job.output_json
    return _to_out(job)


@router.post("/{job_id}/retry", response_model=ImageJobOut)
async def retry_image_job(
    job_id: str,
    background_tasks: BackgroundTasks,
    artisan_tuple: tuple[User, ArtisanProfile] = Depends(get_current_artisan),
    db: AsyncSession = Depends(get_db),
):
    """Retry the existing failed job without creating another product or reuploading its original."""
    _, profile = artisan_tuple
    locked = await db.execute(
        select(ImageProcessingJob)
        .where(ImageProcessingJob.id == job_id, ImageProcessingJob.artisan_id == profile.id)
        .with_for_update()
    )
    job = locked.scalar_one_or_none()
    if not job:
        raise HTTPException(status_code=404, detail="Image job not found")
    if job.product_id:
        product = await db.get(Product, job.product_id)
        if product is None or product.artisan_id != profile.id:
            raise HTTPException(status_code=404, detail="Product not found for this artisan")
        if product.status.value != "draft":
            raise HTTPException(status_code=409, detail="Only a draft product can be reprocessed")
    try:
        job = await retry_existing_job(db, job)
    except ValueError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    if job.crewai_execution_id:
        background_tasks.add_task(_background_refresh, job.id, profile.id)
    return _to_out(job)


@router.get("/latest", response_model=ImageJobOut)
async def get_latest_image_job(
    artisan_tuple: tuple[User, ArtisanProfile] = Depends(get_current_artisan),
    db: AsyncSession = Depends(get_db),
):
    """Get the latest image processing job for the authenticated artisan."""
    user, profile = artisan_tuple
    stmt = (
        select(ImageProcessingJob)
        .where(ImageProcessingJob.artisan_id == profile.id)
        .order_by(ImageProcessingJob.created_at.desc())
        .limit(1)
    )
    result = await db.execute(stmt)
    job = result.scalar_one_or_none()
    if not job:
        raise HTTPException(status_code=404, detail="No image jobs found")
    await refresh_job_from_crewai(db, job)
    return _to_out(job)


@router.get("/{job_id}", response_model=ImageJobOut)
async def get_image_job(
    job_id: str,
    artisan_tuple: tuple[User, ArtisanProfile] = Depends(get_current_artisan),
    db: AsyncSession = Depends(get_db),
):
    """Retrieve job details and poll CrewAI status if still in progress."""
    user, profile = artisan_tuple
    job = await get_job_for_artisan(db, job_id, profile.id)
    if not job:
        # Check MongoDB fallback
        mongo_doc = await get_image_job_mongo(job_id, profile.id)
        if mongo_doc:
            return ImageJobOut(**mongo_doc)
        raise HTTPException(status_code=404, detail="Image job not found")
    await refresh_job_from_crewai(db, job)
    return _to_out(job)


@router.get("/{job_id}/output")
async def get_image_job_output(
    job_id: str,
    artisan_tuple: tuple[User, ArtisanProfile] = Depends(get_current_artisan),
    db: AsyncSession = Depends(get_db),
):
    """Read the persisted JSON result from MongoDB for the owning artisan."""
    _, profile = artisan_tuple
    job = await get_job_for_artisan(db, job_id, profile.id)
    if not job:
        raise HTTPException(status_code=404, detail="Image job not found")
    try:
        mongo_doc = await get_image_job_mongo(job_id, profile.id)
    except Exception as exc:
        raise HTTPException(status_code=503, detail="MongoDB image output is unavailable") from exc
    output_json = mongo_doc.get("output_json") if mongo_doc else None
    if not output_json:
        if job.status in {"running", "queued"}:
            raise HTTPException(status_code=409, detail="Image processing has not produced output yet")
        raise HTTPException(status_code=404, detail="No MongoDB output is saved for this image job")
    return {"job_id": job_id, "output_json": output_json}


@router.put("/{job_id}/selection", response_model=ImageJobOut)
async def put_image_variant_selection(
    job_id: str,
    payload: SelectVariantsIn,
    artisan_tuple: tuple[User, ArtisanProfile] = Depends(get_current_artisan),
    db: AsyncSession = Depends(get_db),
):
    """Save exactly three valid variant IDs to MongoDB and database."""
    user, profile = artisan_tuple
    job = await get_job_for_artisan(db, job_id, profile.id)
    if not job:
        raise HTTPException(status_code=404, detail="Image job not found")
    try:
        await apply_variant_selection(job, payload.variant_ids)
        await db.commit()
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except RuntimeError as exc:
        await db.rollback()
        raise HTTPException(status_code=503, detail="Image selection could not be saved") from exc
    return _to_out(job)


@router.post("/{job_id}/select", response_model=ImageJobOut)
async def post_image_variant_selection(
    job_id: str,
    payload: SelectVariantsIn,
    artisan_tuple: tuple[User, ArtisanProfile] = Depends(get_current_artisan),
    db: AsyncSession = Depends(get_db),
):
    """Alias for selection endpoint (accepts POST)."""
    return await put_image_variant_selection(job_id, payload, artisan_tuple, db)


@router.post("/{job_id}/review", response_model=ImageJobOut)
async def review_image_job(
    job_id: str,
    payload: ReviewImageJobIn,
    artisan_tuple: tuple[User, ArtisanProfile] = Depends(get_current_artisan),
    db: AsyncSession = Depends(get_db),
):
    """Require the artisan to inspect uncertain segmentation before selection or publication."""
    _, profile = artisan_tuple
    job = await get_job_for_artisan(db, job_id, profile.id)
    if not job:
        raise HTTPException(status_code=404, detail="Image job not found")
    if job.status != "awaiting_review":
        raise HTTPException(status_code=409, detail="This image job is not awaiting review")
    usable = [v for v in (job.variants or []) if isinstance(v, dict) and v.get("image_url") and v.get("status") != "missing_image"]
    if payload.approved:
        if len(usable) < 3 or job.segmentation_status in {"failed", "retake_required", "unsafe", "rejected"}:
            raise HTTPException(status_code=409, detail="This result cannot be approved; retake the product photo")
        job.requires_review = False
        job.status = "completed"
        if job.product_id:
            product = await db.get(Product, job.product_id)
            if product and product.artisan_id == profile.id:
                product.processing_status = "ready"
                product.ai_processing_result = job.output_json
    else:
        job.requires_review = True
        job.status = "retake_required"
        if job.product_id:
            product = await db.get(Product, job.product_id)
            if product and product.artisan_id == profile.id:
                product.processing_status = "failed"
    if job.output_json is not None:
        agent_output = {
            **job.output_json.get("agent_output", {}),
            "status": job.status,
            "job_status": job.status,
            "requires_review": job.requires_review,
        }
        job.output_json = {
            **job.output_json,
            "status": job.status,
            "requires_review": job.requires_review,
            "agent_output": agent_output,
        }
    try:
        await save_image_job_mongo(job_to_mongo_dict(job))
    except Exception as exc:
        from app.config import settings
        if settings.MONGODB_REQUIRED:
            raise HTTPException(status_code=503, detail="Image review could not be saved to MongoDB") from exc
    await db.commit()
    return _to_out(job)
