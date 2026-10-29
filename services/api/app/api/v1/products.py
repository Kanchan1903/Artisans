"""Product router: Catalog browsing, filters, search, artisan CRUD, stock updates."""
import io
import httpx
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile, File, Form, status
from sqlalchemy import select, func, or_
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.models.user import User
from app.models.artisan import ArtisanProfile
from app.models.product import Product, ProductImage, ProductTranslation, Category, ProductStatus
from app.models.pricing_revision import PricingRevision
from app.models.review import Review
from app.schemas.product import (
    ProductCreate,
    ProductUpdate,
    ProductPublishIn,
    ProductOut,
    ProductStockUpdate,
    CategoryOut,
    ProductListResponse,
    ReviewCreate,
    ReviewOut,
    ProductImageCreate,
    ProductDescriptionTranslationIn,
    ProductDescriptionTranslationOut,
    VOICE_LANGUAGES,
)
from app.schemas.pricing import (
    PricingRecommendationIn,
    PricingChallengeIn,
    PricingSelectionIn,
    PricingRecommendationOut,
)
from app.utils.pricing_comparables import PRICING_VERSION, build_storefront_recommendation
from app.config import settings
from app.core.dependencies import get_current_artisan, get_optional_user, get_current_user
from app.models.user import UserRole
from app.utils.storage import storage
from app.utils.events import event_broker
from app.utils.image_jobs import apply_variant_selection, get_job_for_artisan, selected_variant_records

router = APIRouter(prefix="/products", tags=["Products"])


async def _owned_draft(product_id: int, artisan_id: int, db: AsyncSession) -> Product:
    result = await db.execute(
        select(Product)
        .where(Product.id == product_id, Product.artisan_id == artisan_id)
        .options(selectinload(Product.category))
    )
    product = result.scalar_one_or_none()
    if product is None:
        raise HTTPException(status_code=404, detail="Product draft not found")
    if product.status != ProductStatus.draft:
        raise HTTPException(status_code=409, detail="Pricing review is available only for an unpublished draft")
    return product


def _pricing_revision_out(revision: PricingRevision) -> dict:
    return {
        "revision_id": revision.id,
        "product_id": revision.product_id,
        "version": revision.version,
        "suggested_price": revision.suggested_price,
        "currency": revision.currency,
        "price_range_min": revision.price_range_min,
        "price_range_max": revision.price_range_max,
        "comparable_products": revision.comparable_products or [],
        "comparison_summary": revision.comparison_summary,
        "pricing_factors": revision.pricing_factors or [],
        "confidence": revision.confidence,
        "requires_review": revision.requires_review,
        "pricing_version": revision.pricing_version,
        "error": revision.error,
        "challenge_reason": revision.challenge_reason,
        "challenge_context": revision.challenge_context,
        "previous_revision_id": revision.previous_revision_id,
        "selected_price": revision.selected_price,
        "selection_source": revision.selection_source,
        "created_at": revision.created_at.isoformat() if revision.created_at else "",
    }


async def _save_pricing_revision(
    *,
    product: Product,
    artisan_id: int,
    db: AsyncSession,
    request: PricingRecommendationIn,
    challenge_reason: str | None = None,
    challenge_context: str | None = None,
    previous_revision_id: int | None = None,
) -> PricingRevision:
    if request.idempotency_key:
        existing_result = await db.execute(
            select(PricingRevision).where(
                PricingRevision.product_id == product.id,
                PricingRevision.idempotency_key == request.idempotency_key,
            )
        )
        existing = existing_result.scalar_one_or_none()
        if existing:
            return existing

    category_slug = product.category.slug if product.category else None
    if not category_slug:
        raise HTTPException(status_code=422, detail="Select a valid product category before pricing")

    candidates_result = await db.execute(
        select(Product)
        .where(
            Product.category_id == product.category_id,
            Product.status == ProductStatus.published,
            Product.price > 0,
            Product.id != product.id,
        )
        .options(selectinload(Product.category))
        .order_by(Product.updated_at.desc(), Product.id.desc())
        .limit(1000)
    )
    candidates = candidates_result.scalars().all()
    costs = {
        "material_cost": request.material_cost,
        "labor_hours": request.labor_hours,
        "hourly_rate": request.hourly_rate,
        "packaging_cost": request.packaging_cost,
        "shipping_cost": request.shipping_cost,
    }
    snapshot = build_storefront_recommendation(
        product,
        candidates,
        currency=settings.CURRENCY_CODE.upper(),
        costs=costs,
    )
    version_result = await db.execute(
        select(func.max(PricingRevision.version)).where(
            PricingRevision.product_id == product.id
        )
    )
    version = (version_result.scalar_one() or 0) + 1
    revision = PricingRevision(
        product_id=product.id,
        artisan_id=artisan_id,
        version=version,
        pricing_version=PRICING_VERSION,
        currency=settings.CURRENCY_CODE.upper(),
        suggested_price=snapshot["suggested_price"],
        price_range_min=snapshot["price_range_min"],
        price_range_max=snapshot["price_range_max"],
        comparable_products=snapshot["comparable_products"],
        comparison_summary=snapshot["comparison_summary"],
        pricing_factors=snapshot["pricing_factors"],
        confidence=snapshot["confidence"],
        requires_review=snapshot["requires_review"],
        error=snapshot["error"],
        challenge_reason=challenge_reason,
        challenge_context=challenge_context,
        previous_revision_id=previous_revision_id,
        idempotency_key=request.idempotency_key,
    )
    db.add(revision)
    await db.commit()
    await db.refresh(revision)
    return revision


async def _ensure_selected_price_before_publish(
    product_id: int, artisan_id: int, db: AsyncSession
) -> float | None:
    history_result = await db.execute(
        select(PricingRevision)
        .where(
            PricingRevision.product_id == product_id,
            PricingRevision.artisan_id == artisan_id,
        )
        .order_by(PricingRevision.version.desc())
    )
    latest = history_result.scalars().first()
    if latest is not None and latest.selected_price is None:
        raise HTTPException(
            status_code=409,
            detail="Choose a suggested or custom price before publishing this product",
        )
    return latest.selected_price if latest is not None else None


@router.post(
    "/{product_id}/pricing/recommendations",
    response_model=PricingRecommendationOut,
)
async def create_product_price_recommendation(
    product_id: int,
    payload: PricingRecommendationIn,
    artisan_tuple: tuple[User, ArtisanProfile] = Depends(get_current_artisan),
    db: AsyncSession = Depends(get_db),
):
    """Snapshot a fresh, deterministic comparison against published storefront products."""
    _, profile = artisan_tuple
    product = await _owned_draft(product_id, profile.id, db)
    revision = await _save_pricing_revision(
        product=product, artisan_id=profile.id, db=db, request=payload
    )
    return _pricing_revision_out(revision)


@router.post(
    "/{product_id}/pricing/challenges",
    response_model=PricingRecommendationOut,
)
async def challenge_product_price_recommendation(
    product_id: int,
    payload: PricingChallengeIn,
    artisan_tuple: tuple[User, ArtisanProfile] = Depends(get_current_artisan),
    db: AsyncSession = Depends(get_db),
):
    """Record the artisan's challenge and fetch a new live snapshot for a single recheck."""
    _, profile = artisan_tuple
    product = await _owned_draft(product_id, profile.id, db)
    previous_result = await db.execute(
        select(PricingRevision).where(
            PricingRevision.id == payload.previous_revision_id,
            PricingRevision.product_id == product.id,
            PricingRevision.artisan_id == profile.id,
        )
    )
    previous = previous_result.scalar_one_or_none()
    if previous is None:
        raise HTTPException(status_code=404, detail="Pricing recommendation not found")
    revision = await _save_pricing_revision(
        product=product,
        artisan_id=profile.id,
        db=db,
        request=payload,
        challenge_reason=payload.reason,
        challenge_context=payload.context,
        previous_revision_id=previous.id,
    )
    return _pricing_revision_out(revision)


@router.get("/{product_id}/pricing/history", response_model=list[PricingRecommendationOut])
async def get_product_pricing_history(
    product_id: int,
    artisan_tuple: tuple[User, ArtisanProfile] = Depends(get_current_artisan),
    db: AsyncSession = Depends(get_db),
):
    """Return recommendation snapshots only to the artisan who owns the product."""
    _, profile = artisan_tuple
    product_result = await db.execute(
        select(Product).where(
            Product.id == product_id,
            Product.artisan_id == profile.id,
        )
    )
    if product_result.scalar_one_or_none() is None:
        raise HTTPException(status_code=404, detail="Product not found")
    result = await db.execute(
        select(PricingRevision)
        .where(
            PricingRevision.product_id == product_id,
            PricingRevision.artisan_id == profile.id,
        )
        .order_by(PricingRevision.version.asc())
    )
    return [_pricing_revision_out(row) for row in result.scalars().all()]


@router.put("/{product_id}/pricing/selection", response_model=PricingRecommendationOut)
async def select_product_price(
    product_id: int,
    payload: PricingSelectionIn,
    artisan_tuple: tuple[User, ArtisanProfile] = Depends(get_current_artisan),
    db: AsyncSession = Depends(get_db),
):
    """Save the artisan-approved price without publishing the product."""
    _, profile = artisan_tuple
    product = await _owned_draft(product_id, profile.id, db)
    revision_result = await db.execute(
        select(PricingRevision).where(
            PricingRevision.id == payload.revision_id,
            PricingRevision.product_id == product.id,
            PricingRevision.artisan_id == profile.id,
        )
    )
    revision = revision_result.scalar_one_or_none()
    if revision is None:
        raise HTTPException(status_code=404, detail="Pricing recommendation not found")
    latest_result = await db.execute(
        select(func.max(PricingRevision.version)).where(
            PricingRevision.product_id == product.id
        )
    )
    if revision.version != latest_result.scalar_one():
        raise HTTPException(status_code=409, detail="This recommendation is stale. Refresh pricing before selecting.")
    if payload.selection_source in {"suggested", "revised_suggestion"}:
        if revision.suggested_price is None:
            raise HTTPException(status_code=409, detail="There is no supported suggestion to accept; set your own price instead")
        if abs(payload.price - revision.suggested_price) > 0.01:
            raise HTTPException(status_code=422, detail="Accepted price must match the current suggestion")

    product.price = round(payload.price, 2)
    revision.selected_price = product.price
    revision.selection_source = payload.selection_source
    revision.selected_at = datetime.now(timezone.utc)
    await db.commit()
    await db.refresh(revision)
    return _pricing_revision_out(revision)


@router.post("/translate-description", response_model=ProductDescriptionTranslationOut)
async def translate_product_description(
    payload: ProductDescriptionTranslationIn,
    artisan_tuple: tuple[User, ArtisanProfile] = Depends(get_current_artisan),
    db: AsyncSession = Depends(get_db),
):
    """Translate artisan-provided speech only; the caller must confirm edits before saving."""
    _, profile = artisan_tuple
    source = payload.source_language.lower()
    target = payload.target_language.lower()
    transcript = payload.transcript.strip()
    if source not in VOICE_LANGUAGES:
        raise HTTPException(status_code=400, detail="Source language is not supported")
    if target != "en":
        raise HTTPException(status_code=400, detail="Only English product descriptions are supported")
    if len(transcript) < 2:
        raise HTTPException(status_code=422, detail="Please speak or enter a clearer description")
    if payload.product_id is not None:
        result = await db.execute(
            select(Product).where(
                Product.id == payload.product_id,
                Product.artisan_id == profile.id,
            )
        )
        if result.scalar_one_or_none() is None:
            raise HTTPException(status_code=404, detail="Product not found for this artisan")

    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(30.0)) as client:
            response = await client.post(
                f"{settings.AI_SERVICE_URL.rstrip('/')}/ai/product-description",
                json={
                    "source_language": source,
                    "target_language": target,
                    "transcript": transcript,
                },
            )
        response.raise_for_status()
        result = response.json()
        description = result.get("english_description")
        if not isinstance(description, str) or not description.strip():
            raise ValueError("Missing translation")
        return ProductDescriptionTranslationOut(
            success=True,
            source_language=source,
            original_transcript=transcript,
            english_description=description.strip(),
            requires_review=bool(result.get("requires_review", True)),
        )
    except (httpx.HTTPError, ValueError, TypeError):
        return ProductDescriptionTranslationOut(
            success=False,
            source_language=source,
            original_transcript=transcript,
            requires_review=True,
            error="Translation is temporarily unavailable. Your transcript is preserved; retry or edit it.",
        )

async def _sync_product_to_mongo(prod: Product, image_job_id: str | None = None) -> None:
    from app.mongodb import save_product_mongo
    try:
        primary_url = None
        images_list = []
        for img in (prod.images or []):
            images_list.append(img.url)
            if img.is_primary and not primary_url:
                primary_url = img.url
        if not primary_url and images_list:
            primary_url = images_list[0]

        cat_name = prod.category.name if prod.category else "Uncategorized"
        doc = {
            "product_id": str(prod.id),
            "artisan_id": str(prod.artisan_id),
            "name": prod.title_en,
            "category": cat_name,
            "description": prod.description_en or "",
            "image_job_id": image_job_id or getattr(prod, "image_job_id", None),
            "images": images_list,
            "primary_image_url": primary_url,
            "status": prod.status.value if hasattr(prod.status, "value") else str(prod.status),
            "created_at": prod.created_at,
            "updated_at": prod.updated_at,
        }
        await save_product_mongo(doc)
    except Exception:
        pass



async def _images_from_image_job(payload: ProductCreate, artisan_id: int, db: AsyncSession) -> list[ProductImageCreate]:
    """When an image job is attached, catalog images must be the three selected variants."""
    if not payload.image_job_id:
        return list(payload.images)

    job = await get_job_for_artisan(db, payload.image_job_id, artisan_id)
    if not job:
        raise HTTPException(status_code=400, detail="Image job not found for this artisan")
    if job.status == "retake_required":
        raise HTTPException(status_code=400, detail="Cannot publish: photo must be retaken")
    if job.status != "completed" or job.requires_review:
        raise HTTPException(status_code=400, detail="Cannot publish until image processing and required human review complete")
    if payload.selected_variant_ids:
        try:
            await apply_variant_selection(job, payload.selected_variant_ids)
        except ValueError as exc:
            raise HTTPException(status_code=400, detail=str(exc)) from exc
    records = selected_variant_records(job)
    urls = [str(item.get("image_url") or "").strip() for item in records]
    if len(records) != 3 or len(set(urls)) != 3 or any(not url.startswith(("http://", "https://")) for url in urls):
        raise HTTPException(status_code=400, detail="Select exactly three processed variants before saving")
    if any(item.get("status") == "missing_image" or item.get("saved") is False for item in records):
        raise HTTPException(status_code=400, detail="One or more selected images were not successfully stored")
    return [
        ProductImageCreate(url=item["image_url"], is_primary=idx == 0, order_index=idx)
        for idx, item in enumerate(records)
    ]


async def _link_job_to_product(job_id: str | None, artisan_id: int, product_id: int, db: AsyncSession) -> None:
    if not job_id:
        return
    job = await get_job_for_artisan(db, job_id, artisan_id)
    if not job:
        raise HTTPException(status_code=400, detail="Image job not found for this artisan")
    if job.product_id not in (None, product_id):
        raise HTTPException(status_code=409, detail="This image job is already attached to another product")
    job.product_id = product_id
    if job.output_json is not None:
        agent_output = {**job.output_json.get("agent_output", {}), "product_id": str(product_id)}
        job.output_json = {**job.output_json, "product_id": str(product_id), "agent_output": agent_output}
    from app.mongodb import save_image_job_mongo
    from app.utils.image_jobs import job_to_mongo_dict
    try:
        await save_image_job_mongo(job_to_mongo_dict(job))
    except Exception as exc:
        from app.config import settings
        if settings.MONGODB_REQUIRED:
            raise HTTPException(status_code=503, detail="Image job output could not be synchronized to MongoDB") from exc


@router.get("/categories", response_model=list[CategoryOut])
async def list_categories(db: AsyncSession = Depends(get_db)):
    """List all craft categories."""
    stmt = select(Category).order_by(Category.name.asc())
    result = await db.execute(stmt)
    return result.scalars().all()


MAX_PRODUCT_IMAGE_BYTES = 10 * 1024 * 1024
SUPPORTED_PRODUCT_IMAGE_FORMATS = {
    "JPEG": ("image/jpeg", ".jpg"),
    "PNG": ("image/png", ".png"),
    "WEBP": ("image/webp", ".webp"),
}


def _validate_product_image(file_bytes: bytes) -> tuple[str, str]:
    if not file_bytes:
        raise HTTPException(status_code=400, detail="The selected image is empty.")
    if len(file_bytes) > MAX_PRODUCT_IMAGE_BYTES:
        raise HTTPException(status_code=413, detail="Image must be 10 MB or smaller.")

    try:
        from PIL import Image
        with Image.open(io.BytesIO(file_bytes)) as image:
            image_format = image.format
            width, height = image.size
            image.verify()
        if image_format not in SUPPORTED_PRODUCT_IMAGE_FORMATS:
            raise HTTPException(status_code=415, detail="Use a JPEG, PNG, or WebP image.")
        if width <= 0 or height <= 0 or width * height > 40_000_000:
            raise HTTPException(status_code=400, detail="Image dimensions are invalid or too large.")
        return SUPPORTED_PRODUCT_IMAGE_FORMATS[image_format]
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=415, detail="The selected file is not a valid JPEG, PNG, or WebP image.") from exc


@router.post("/upload-image", status_code=status.HTTP_201_CREATED)
async def upload_product_image(
    file: UploadFile = File(...),
    upload_id: str = Form(..., min_length=1, max_length=64),
    product_id: int | None = Form(default=None, gt=0),
    category_slug: str | None = Form(default=None, max_length=100),
    artisan_tuple: tuple[User, ArtisanProfile] = Depends(get_current_artisan),
    db: AsyncSession = Depends(get_db),
):
    """Store an artisan's original photo and attach it to an owned draft, without AI processing."""
    _, profile = artisan_tuple
    if not upload_id.strip() or any(ord(char) < 33 for char in upload_id):
        raise HTTPException(status_code=400, detail="Invalid upload ID.")

    file_bytes = await file.read(MAX_PRODUCT_IMAGE_BYTES + 1)
    content_type, extension = _validate_product_image(file_bytes)

    prior_result = await db.execute(
        select(ProductImage, Product)
        .join(Product, Product.id == ProductImage.product_id)
        .where(ProductImage.upload_key == upload_id)
    )
    prior = prior_result.first()
    if prior:
        prior_image, prior_product = prior
        if prior_product.artisan_id != profile.id or (product_id is not None and prior_product.id != product_id):
            raise HTTPException(status_code=409, detail="This upload ID is already in use.")
        return {
            "product_id": prior_product.id,
            "image_id": prior_image.id,
            "image_url": prior_image.url,
            "status": prior_product.status.value,
        }

    product = None
    if product_id is not None:
        product_result = await db.execute(
            select(Product)
            .where(Product.id == product_id, Product.artisan_id == profile.id)
            .options(selectinload(Product.images), selectinload(Product.category), selectinload(Product.translations))
        )
        product = product_result.scalar_one_or_none()
        if not product:
            raise HTTPException(status_code=404, detail="Draft product not found.")
        if product.status != ProductStatus.draft:
            raise HTTPException(status_code=409, detail="Photos can only be uploaded to a draft product.")

    if category_slug:
        category_result = await db.execute(select(Category).where(Category.slug == category_slug))
        category = category_result.scalar_one_or_none()
        if not category:
            raise HTTPException(status_code=400, detail="Unknown product category.")
    else:
        category = None

    filename = f"{upload_id}{extension}"
    try:
        url = await storage.upload_file(file_bytes, filename=filename, content_type=content_type)
    except Exception as exc:
        raise HTTPException(status_code=503, detail="Image storage is unavailable. Please retry.") from exc

    if product is None:
        product = Product(
            artisan_id=profile.id,
            category_id=category.id if category else None,
            title_en="Handcrafted Product Draft",
            price=0,
            stock=0,
            status=ProductStatus.draft,
            ai_generated=False,
            images=[],
        )
        db.add(product)
        await db.flush()

    # Keep the uploaded original as the single image on a draft; later AI variants
    # can replace it through the existing image-job and publishing workflow.
    previous_urls = [image.url for image in product.images]
    product.images.clear()
    image = ProductImage(
        product_id=product.id,
        url=url,
        is_primary=True,
        order_index=0,
        upload_key=upload_id,
    )
    product.images.append(image)
    try:
        await db.commit()
    except Exception:
        await db.rollback()
        await storage.delete_file(url)
        raise HTTPException(status_code=503, detail="The photo could not be attached to the draft. Please retry.")

    saved_result = await db.execute(
        select(Product)
        .where(Product.id == product.id)
        .options(selectinload(Product.images), selectinload(Product.category))
    )
    product = saved_result.scalar_one()
    await db.refresh(image)
    await _sync_product_to_mongo(product)
    for old_url in previous_urls:
        if old_url != url:
            await storage.delete_file(old_url)
    return {
        "product_id": product.id,
        "image_id": image.id,
        "image_url": url,
        "status": product.status.value,
    }


@router.delete("/upload-image/{upload_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_uploaded_product_image(
    upload_id: str,
    artisan_tuple: tuple[User, ArtisanProfile] = Depends(get_current_artisan),
    db: AsyncSession = Depends(get_db),
):
    """Remove an uploaded original from this artisan's draft; repeated deletes are safe."""
    _, profile = artisan_tuple
    result = await db.execute(
        select(ProductImage, Product)
        .join(Product, Product.id == ProductImage.product_id)
        .where(ProductImage.upload_key == upload_id, Product.artisan_id == profile.id)
        .options(selectinload(Product.images), selectinload(Product.category))
    )
    found = result.first()
    if not found:
        return None
    image, product = found
    if product.status != ProductStatus.draft:
        raise HTTPException(status_code=409, detail="Photos can only be removed from a draft product.")
    product.images.remove(image)
    await db.delete(image)
    await db.commit()
    await storage.delete_file(image.url)
    await _sync_product_to_mongo(product)
    return None


@router.get("", response_model=ProductListResponse)
async def list_products(
    category_id: int | None = Query(None, description="Filter by category ID"),
    state: str | None = Query(None, description="Filter by artisan state"),
    min_price: float | None = Query(None, ge=0.0),
    max_price: float | None = Query(None, ge=0.0),
    search: str | None = Query(None, description="Search by title, material, or keywords"),
    artisan_id: int | None = Query(None, description="Filter by artisan ID"),
    language: str = Query("en", description="Target language for preferred translation"),
    page: int = Query(1, ge=1),
    size: int = Query(12, ge=1, le=50),
    db: AsyncSession = Depends(get_db),
):
    """Browse public published products with rich multi-faceted filtering."""
    query = (
        select(Product)
        .where(Product.status == ProductStatus.published)
        .options(
            selectinload(Product.images),
            selectinload(Product.translations),
            selectinload(Product.category),
            selectinload(Product.artisan).selectinload(ArtisanProfile.user),
        )
    )

    if category_id is not None:
        query = query.where(Product.category_id == category_id)

    if state:
        query = query.join(Product.artisan).where(ArtisanProfile.state.ilike(f"%{state}%"))

    if min_price is not None:
        query = query.where(Product.price >= min_price)

    if max_price is not None:
        query = query.where(Product.price <= max_price)

    if search:
        search_term = f"%{search}%"
        query = query.where(
            or_(
                Product.title_en.ilike(search_term),
                Product.title_hi.ilike(search_term),
                Product.material.ilike(search_term),
                Product.technique.ilike(search_term),
            )
        )

    if artisan_id is not None:
        query = query.where(Product.artisan_id == artisan_id)

    # Count total
    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar_one()

    # Pagination
    offset = (page - 1) * size
    query = query.order_by(Product.id.desc()).offset(offset).limit(size)
    result = await db.execute(query)
    products = result.scalars().all()

    return ProductListResponse(
        items=products,
        total=total,
        page=page,
        size=size,
    )


@router.get("/artisan/me", response_model=list[ProductOut])
async def list_artisan_my_products(
    artisan_tuple: tuple[User, ArtisanProfile] = Depends(get_current_artisan),
    db: AsyncSession = Depends(get_db),
):
    """Artisan view: all products (drafts, published, hidden)."""
    user, profile = artisan_tuple
    stmt = (
        select(Product)
        .where(Product.artisan_id == profile.id)
        .options(
            selectinload(Product.images),
            selectinload(Product.translations),
            selectinload(Product.category),
            selectinload(Product.artisan).selectinload(ArtisanProfile.user),
        )
        .order_by(Product.id.desc())
    )
    result = await db.execute(stmt)
    return result.scalars().all()


@router.get("/{product_id}", response_model=ProductOut)
async def get_product_detail(
    product_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User | None = Depends(get_optional_user),
):
    """Get single product details with full translations and artisan information.

    Draft, hidden, rejected, and otherwise unpublished products are not public.
    """
    stmt = (
        select(Product)
        .where(Product.id == product_id)
        .options(
            selectinload(Product.images),
            selectinload(Product.translations),
            selectinload(Product.category),
            selectinload(Product.artisan).selectinload(ArtisanProfile.user),
        )
    )
    result = await db.execute(stmt)
    product = result.scalar_one_or_none()

    if not product:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")

    if product.status != ProductStatus.published:
        if current_user is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")
        if current_user.role == UserRole.admin:
            return product
        owner_user_id = product.artisan.user_id if product.artisan else None
        if current_user.id != owner_user_id:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")

    return product


@router.post("", response_model=ProductOut, status_code=status.HTTP_201_CREATED)
async def create_product(
    payload: ProductCreate,
    artisan_tuple: tuple[User, ArtisanProfile] = Depends(get_current_artisan),
    db: AsyncSession = Depends(get_db),
):
    """Artisan publishes or creates a new handcrafted product with idempotency and duplicate prevention."""
    user, profile = artisan_tuple
    if payload.status == ProductStatus.published:
        raise HTTPException(
            status_code=409,
            detail="Products must be saved as drafts and published through the final review endpoint.",
        )
    now = datetime.now(timezone.utc)
    category_id = payload.category_id
    if payload.category_slug:
        category_result = await db.execute(select(Category).where(Category.slug == payload.category_slug))
        category = category_result.scalar_one_or_none()
        if not category:
            raise HTTPException(status_code=400, detail="Unknown product category")
        if category_id is not None and category_id != category.id:
            raise HTTPException(status_code=400, detail="Category ID and slug do not match")
        category_id = category.id
    payload_images = await _images_from_image_job(payload, profile.id, db)

    # 1. Idempotency Check: Prevent duplicate publishing from network retries
    if payload.idempotency_key:
        stmt = (
            select(Product)
            .where(Product.idempotency_key == payload.idempotency_key, Product.artisan_id == profile.id)
            .options(
                selectinload(Product.images),
                selectinload(Product.translations),
                selectinload(Product.category),
                selectinload(Product.artisan).selectinload(ArtisanProfile.user),
            )
        )
        res = await db.execute(stmt)
        existing = res.scalar_one_or_none()
        if existing:
            await _link_job_to_product(payload.image_job_id, profile.id, existing.id, db)
            await db.commit()
            return existing

    # 2. Draft Conversion: Update existing draft instead of creating a duplicate row
    if payload.draft_product_id:
        stmt = (
            select(Product)
            .where(Product.id == payload.draft_product_id, Product.artisan_id == profile.id)
            .options(
                selectinload(Product.images),
                selectinload(Product.translations),
                selectinload(Product.category),
                selectinload(Product.artisan).selectinload(ArtisanProfile.user),
            )
        )
        res = await db.execute(stmt)
        draft_prod = res.scalar_one_or_none()
        if draft_prod:
            if payload.status == ProductStatus.published:
                selected_price = await _ensure_selected_price_before_publish(
                    draft_prod.id, profile.id, db
                )
                if selected_price is not None and abs(payload.price - selected_price) > 0.01:
                    raise HTTPException(
                        status_code=409,
                        detail="Publish price does not match the artisan's approved price",
                    )
            draft_prod.category_id = category_id
            draft_prod.title_en = payload.title_en
            draft_prod.description_en = payload.description_en
            draft_prod.title_hi = payload.title_hi
            draft_prod.description_hi = payload.description_hi
            draft_prod.material = payload.material
            draft_prod.technique = payload.technique
            draft_prod.care_instructions = payload.care_instructions
            draft_prod.seo_keywords = payload.seo_keywords or []
            draft_prod.price = payload.price
            draft_prod.stock = payload.stock
            draft_prod.status = payload.status
            draft_prod.voice_transcript = payload.voice_transcript
            draft_prod.voice_language = payload.voice_language
            draft_prod.ai_generated = payload.ai_generated
            if payload.idempotency_key:
                draft_prod.idempotency_key = payload.idempotency_key
            if payload.status == ProductStatus.published and not draft_prod.published_at:
                draft_prod.published_at = now

            if payload_images:
                draft_prod.images.clear()
                for idx, img in enumerate(payload_images):
                    p_img = ProductImage(
                        product_id=draft_prod.id,
                        url=img.url,
                        is_primary=img.is_primary or (idx == 0),
                        order_index=img.order_index or idx,
                    )
                    draft_prod.images.append(p_img)

            if payload.translations:
                draft_prod.translations.clear()
                for tr in payload.translations:
                    p_tr = ProductTranslation(
                        product_id=draft_prod.id,
                        language=tr.language,
                        title=tr.title,
                        description=tr.description,
                    )
                    draft_prod.translations.append(p_tr)

            await _link_job_to_product(payload.image_job_id, profile.id, draft_prod.id, db)

            await db.commit()

            # Refetch
            refetch_stmt = (
                select(Product)
                .where(Product.id == draft_prod.id)
                .options(
                    selectinload(Product.images),
                    selectinload(Product.translations),
                    selectinload(Product.category),
                    selectinload(Product.artisan).selectinload(ArtisanProfile.user),
                )
            )
            refetch_res = await db.execute(refetch_stmt)
            updated_prod = refetch_res.scalar_one()

            if updated_prod.status == ProductStatus.published:
                await event_broker.publish(
                    "product_published",
                    {
                        "product_id": updated_prod.id,
                        "title": updated_prod.title_en,
                        "price": updated_prod.price,
                        "artisan_name": user.name,
                        "state": profile.state,
                        "image_url": updated_prod.images[0].url if updated_prod.images else None,
                    },
                )
            await _sync_product_to_mongo(updated_prod, payload.image_job_id)
            return updated_prod

    # 3. Create fresh product
    product = Product(
        artisan_id=profile.id,
        category_id=category_id,
        title_en=payload.title_en,
        description_en=payload.description_en,
        title_hi=payload.title_hi,
        description_hi=payload.description_hi,
        material=payload.material,
        technique=payload.technique,
        care_instructions=payload.care_instructions,
        seo_keywords=payload.seo_keywords or [],
        price=payload.price,
        stock=payload.stock,
        status=payload.status,
        voice_transcript=payload.voice_transcript,
        voice_language=payload.voice_language,
        ai_generated=payload.ai_generated,
        published_at=now if payload.status == ProductStatus.published else None,
        idempotency_key=payload.idempotency_key,
    )
    db.add(product)
    await db.flush()
    await _link_job_to_product(payload.image_job_id, profile.id, product.id, db)

    for idx, img in enumerate(payload_images):
        p_img = ProductImage(
            product_id=product.id,
            url=img.url,
            is_primary=img.is_primary or (idx == 0),
            order_index=img.order_index or idx,
        )
        db.add(p_img)

    for tr in payload.translations:
        p_tr = ProductTranslation(
            product_id=product.id,
            language=tr.language,
            title=tr.title,
            description=tr.description,
        )
        db.add(p_tr)

    await db.commit()

    stmt = (
        select(Product)
        .where(Product.id == product.id)
        .options(
            selectinload(Product.images),
            selectinload(Product.translations),
            selectinload(Product.category),
            selectinload(Product.artisan).selectinload(ArtisanProfile.user),
        )
    )
    result = await db.execute(stmt)
    full_product = result.scalar_one()

    if full_product.status == ProductStatus.published:
        await event_broker.publish(
            "product_published",
            {
                "product_id": full_product.id,
                "title": full_product.title_en,
                "price": full_product.price,
                "artisan_name": user.name,
                "state": profile.state,
                "image_url": full_product.images[0].url if full_product.images else None,
            },
        )

    await _sync_product_to_mongo(full_product, payload.image_job_id)
    return full_product


@router.post("/{product_id}/publish", response_model=ProductOut)
async def publish_draft_product(
    product_id: int,
    payload: ProductPublishIn,
    artisan_tuple: tuple[User, ArtisanProfile] = Depends(get_current_artisan),
    db: AsyncSession = Depends(get_db),
):
    """Publish an existing draft product to make it immediately visible to website buyers."""
    user, profile = artisan_tuple
    stmt = (
        select(Product)
        .where(Product.id == product_id, Product.artisan_id == profile.id)
        .with_for_update()
        .options(
            selectinload(Product.images),
            selectinload(Product.translations),
            selectinload(Product.category),
            selectinload(Product.artisan).selectinload(ArtisanProfile.user),
        )
    )
    result = await db.execute(stmt)
    product = result.scalar_one_or_none()
    if not product:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found or unauthorized")

    if product.status == ProductStatus.published:
        if product.idempotency_key == payload.idempotency_key:
            return product
        raise HTTPException(status_code=409, detail="This product has already been published")

    if product.status != ProductStatus.draft:
        raise HTTPException(status_code=409, detail="Only a draft product can be published")
    if not payload.description_confirmed or not payload.price_confirmed:
        raise HTTPException(status_code=422, detail="Confirm the saved English description and final price before publishing")
    if not product.title_en or len(product.title_en.strip()) < 2:
        raise HTTPException(status_code=422, detail="A valid product name is required")
    if not product.description_en or not product.description_en.strip():
        raise HTTPException(status_code=422, detail="A reviewed English description is required")
    if not product.category_id:
        raise HTTPException(status_code=422, detail="Select a valid product category before publishing")

    # The selection is checked against the authenticated artisan's job and exact stored outputs.
    job = await get_job_for_artisan(db, payload.image_job_id, profile.id)
    if not job:
        raise HTTPException(status_code=404, detail="Image processing job not found for this artisan")
    if job.product_id not in (None, product.id):
        raise HTTPException(status_code=409, detail="These processed images are already attached to another product")
    if job.status != "completed" or job.requires_review:
        raise HTTPException(status_code=409, detail="Image processing must complete and any required human review must be approved")
    try:
        await apply_variant_selection(job, payload.selected_variant_ids)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail="Image selection could not be saved. Retry publication.") from exc
    selected_records = selected_variant_records(job)
    selected_urls = [str(item.get("image_url") or "").strip() for item in selected_records]
    if (
        len(selected_records) != 3
        or len(set(selected_urls)) != 3
        or any(not url.startswith(("http://", "https://")) for url in selected_urls)
        or any(item.get("status") == "missing_image" or item.get("saved") is False for item in selected_records)
    ):
        raise HTTPException(status_code=422, detail="Exactly three distinct, stored image variants are required")

    selected_price = await _ensure_selected_price_before_publish(
        product.id, profile.id, db
    )
    if selected_price is None:
        raise HTTPException(status_code=409, detail="Choose and save a final price before publishing")
    if abs(payload.price - selected_price) > 0.01 or abs(product.price - selected_price) > 0.01:
        raise HTTPException(
            status_code=409,
            detail="Product price differs from the artisan-approved price",
        )

    product.images.clear()
    for index, item in enumerate(selected_records):
        product.images.append(ProductImage(
            url=selected_urls[index],
            is_primary=index == 0,
            order_index=index,
        ))
    job.product_id = product.id
    product.idempotency_key = payload.idempotency_key

    product.status = ProductStatus.published
    product.published_at = datetime.now(timezone.utc)
    await db.commit()
    from app.mongodb import publish_product_mongo
    await _sync_product_to_mongo(product, payload.image_job_id)
    try:
        await publish_product_mongo(product.id, profile.id)
    except Exception:
        # PostgreSQL is the public catalog source; compensate if a mirror update fails.
        product.status = ProductStatus.draft
        product.published_at = None
        await db.commit()
        raise HTTPException(status_code=503, detail="Product publication could not be synchronized. It remains a draft.")

    # Refetch
    refetch_stmt = (
        select(Product)
        .where(Product.id == product.id)
        .options(
            selectinload(Product.images),
            selectinload(Product.translations),
            selectinload(Product.category),
            selectinload(Product.artisan).selectinload(ArtisanProfile.user),
        )
    )
    product = (await db.execute(refetch_stmt)).scalar_one()

    try:
        await event_broker.publish(
            "product_published",
            {
                "product_id": product.id,
                "title": product.title_en,
                "price": product.price,
                "artisan_name": user.name,
                "state": profile.state,
                "image_url": product.images[0].url if product.images else None,
            },
        )
    except Exception:
        pass
    return product


@router.put("/{product_id}", response_model=ProductOut)
async def update_product(
    product_id: int,
    payload: ProductUpdate,
    artisan_tuple: tuple[User, ArtisanProfile] = Depends(get_current_artisan),
    db: AsyncSession = Depends(get_db),
):
    """Artisan updates their existing product."""
    user, profile = artisan_tuple

    stmt = select(Product).where(Product.id == product_id, Product.artisan_id == profile.id)
    result = await db.execute(stmt)
    product = result.scalar_one_or_none()

    if not product:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found or unauthorized")

    if payload.status == ProductStatus.published and product.status != ProductStatus.published:
        raise HTTPException(status_code=409, detail="Use the final review publish endpoint to publish this product")

    update_data = payload.model_dump(exclude_unset=True)
    category_slug = update_data.pop("category_slug", None)
    category_id = update_data.pop("category_id", None) if "category_id" in update_data else None
    translations = update_data.pop("translations", None)
    if category_slug:
        category_result = await db.execute(select(Category).where(Category.slug == category_slug))
        category = category_result.scalar_one_or_none()
        if not category:
            raise HTTPException(status_code=400, detail="Unknown product category")
        if category_id is not None and category_id != category.id:
            raise HTTPException(status_code=400, detail="Category ID and slug do not match")
        product.category_id = category.id
    elif "category_id" in payload.model_fields_set:
        if category_id is not None:
            category_result = await db.execute(select(Category).where(Category.id == category_id))
            if category_result.scalar_one_or_none() is None:
                raise HTTPException(status_code=400, detail="Unknown product category")
        product.category_id = category_id
    for field, val in update_data.items():
        setattr(product, field, val)
    if translations is not None:
        product.translations.clear()
        for tr in translations:
            product.translations.append(ProductTranslation(
                language=tr["language"],
                title=tr["title"],
                description=tr.get("description"),
            ))

    await db.commit()

    # Reload with relationships
    stmt = (
        select(Product)
        .where(Product.id == product.id)
        .options(
            selectinload(Product.images),
            selectinload(Product.translations),
            selectinload(Product.category),
            selectinload(Product.artisan).selectinload(ArtisanProfile.user),
        )
    )
    result = await db.execute(stmt)
    return result.scalar_one()


@router.patch("/{product_id}/stock", response_model=ProductOut)
async def update_product_stock(
    product_id: int,
    payload: ProductStockUpdate,
    artisan_tuple: tuple[User, ArtisanProfile] = Depends(get_current_artisan),
    db: AsyncSession = Depends(get_db),
):
    """Update stock count (can be triggered by voice command or tap)."""
    user, profile = artisan_tuple
    stmt = select(Product).where(Product.id == product_id, Product.artisan_id == profile.id)
    result = await db.execute(stmt)
    product = result.scalar_one_or_none()

    if not product:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")

    product.stock = payload.stock
    await db.commit()

    stmt = (
        select(Product)
        .where(Product.id == product.id)
        .options(
            selectinload(Product.images),
            selectinload(Product.translations),
            selectinload(Product.category),
            selectinload(Product.artisan).selectinload(ArtisanProfile.user),
        )
    )
    result = await db.execute(stmt)
    return result.scalar_one()


@router.delete("/{product_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_product(
    product_id: int,
    artisan_tuple: tuple[User, ArtisanProfile] = Depends(get_current_artisan),
    db: AsyncSession = Depends(get_db),
):
    """Artisan deletes a product."""
    user, profile = artisan_tuple
    stmt = select(Product).where(Product.id == product_id, Product.artisan_id == profile.id)
    result = await db.execute(stmt)
    product = result.scalar_one_or_none()

    if not product:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")

    await db.delete(product)
    await db.commit()
    return None


@router.post("/{product_id}/reviews", response_model=ReviewOut, status_code=status.HTTP_201_CREATED)
async def create_product_review(
    product_id: int,
    payload: ReviewCreate,
    buyer: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Buyer creates a verified review and rating for a handcrafted product."""
    stmt = select(Product).where(Product.id == product_id)
    result = await db.execute(stmt)
    product = result.scalar_one_or_none()
    if not product:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")

    review = Review(
        product_id=product.id,
        buyer_id=buyer.id,
        rating=payload.rating,
        comment=payload.comment,
    )
    db.add(review)
    await db.commit()
    await db.refresh(review)

    return ReviewOut(
        id=review.id,
        product_id=review.product_id,
        buyer_id=review.buyer_id,
        rating=review.rating,
        comment=review.comment,
        created_at=review.created_at,
        buyer_name=buyer.name,
    )


@router.get("/{product_id}/reviews", response_model=list[ReviewOut])
async def list_product_reviews(
    product_id: int,
    db: AsyncSession = Depends(get_db),
):
    """List all verified reviews for a specific product."""
    stmt = (
        select(Review)
        .where(Review.product_id == product_id)
        .options(selectinload(Review.buyer))
        .order_by(Review.created_at.desc())
    )
    result = await db.execute(stmt)
    reviews = result.scalars().all()
    return reviews
