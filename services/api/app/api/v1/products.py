"""Product router: Catalog browsing, filters, search, artisan CRUD, stock updates."""
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile, File, status
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
)
from app.core.dependencies import get_current_artisan, get_optional_user, get_current_user
from app.utils.storage import storage
from app.utils.events import event_broker

router = APIRouter(prefix="/products", tags=["Products"])


@router.get("/categories", response_model=list[CategoryOut])
async def list_categories(db: AsyncSession = Depends(get_db)):
    """List all craft categories."""
    stmt = select(Category).order_by(Category.name.asc())
    result = await db.execute(stmt)
    return result.scalars().all()


@router.post("/upload-image")
async def upload_product_image(
    file: UploadFile = File(...),
):
    """Upload a raw or AI-enhanced product image to storage and return its public URL."""
    file_bytes = await file.read()
    content_type = file.content_type or "image/jpeg"
    filename = file.filename or "image.jpg"
    url = await storage.upload_file(file_bytes, filename=filename, content_type=content_type)
    return {"url": url, "filename": filename}


@router.get("", response_model=ProductListResponse)
async def list_products(
    category_id: int | None = Query(None, description="Filter by category ID"),
    state: str | None = Query(None, description="Filter by artisan state"),
    min_price: float | None = Query(None, ge=0.0),
    max_price: float | None = Query(None, ge=0.0),
    search: str | None = Query(None, description="Search by title, material, or keywords"),
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
):
    """Get single product details with full translations and artisan information."""
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
            draft_prod.category_id = payload.category_id
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

            if payload.images:
                draft_prod.images.clear()
                for idx, img in enumerate(payload.images):
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
            return updated_prod

    # 3. Create fresh product
    product = Product(
        artisan_id=profile.id,
        category_id=payload.category_id,
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

    for idx, img in enumerate(payload.images):
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

    product.status = ProductStatus.published
    product.published_at = datetime.now(timezone.utc)
    await db.commit()

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
