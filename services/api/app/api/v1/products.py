"""Product router: Catalog browsing, filters, search, artisan CRUD, stock updates."""
import io
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile, File, Form, status
from sqlalchemy import select, func, or_
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.models.user import User
from app.models.artisan import ArtisanProfile
from app.models.product import Product, ProductImage, ProductTranslation, Category, ProductStatus
from app.models.review import Review
from app.schemas.product import (
    ProductCreate,
    ProductUpdate,
    ProductOut,
    ProductStockUpdate,
    CategoryOut,
    ProductListResponse,
    ReviewCreate,
    ReviewOut,
    ProductImageCreate,
)
from app.core.dependencies import get_current_artisan, get_optional_user, get_current_user
from app.models.user import UserRole
from app.utils.storage import storage
from app.utils.events import event_broker
from app.utils.image_jobs import apply_variant_selection, get_job_for_artisan, selected_variant_records

router = APIRouter(prefix="/products", tags=["Products"])

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
    if job.status != "completed":
        raise HTTPException(status_code=400, detail="Cannot publish until image processing completes")
    if payload.selected_variant_ids:
        try:
            await apply_variant_selection(job, payload.selected_variant_ids)
        except ValueError as exc:
            raise HTTPException(status_code=400, detail=str(exc)) from exc
    records = selected_variant_records(job)
    if len(records) != 3:
        raise HTTPException(status_code=400, detail="Select exactly three processed variants before saving")
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
    artisan_tuple: tuple[User, ArtisanProfile] = Depends(get_current_artisan),
    db: AsyncSession = Depends(get_db),
):
    """Publish an existing draft product to make it immediately visible to website buyers."""
    user, profile = artisan_tuple
    stmt = (
        select(Product)
        .where(Product.id == product_id, Product.artisan_id == profile.id)
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
        return product  # Idempotent

    from app.mongodb import publish_product_mongo
    product.status = ProductStatus.published
    product.published_at = datetime.now(timezone.utc)
    await db.commit()
    await publish_product_mongo(product.id, profile.id)

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

    update_data = payload.model_dump(exclude_unset=True)
    for field, val in update_data.items():
        setattr(product, field, val)

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
