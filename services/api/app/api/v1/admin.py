"""Admin router: Artisan onboarding moderation, product approvals, and platform health stats."""
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.models.user import User
from app.models.artisan import ArtisanProfile
from app.models.product import Product, ProductStatus
from app.models.order import Order
from app.models.inquiry import Inquiry
from app.schemas.admin import AdminStatsOut, ArtisanApprovalRequest, ProductModerationRequest
from app.schemas.artisan import ArtisanProfileOut
from app.schemas.product import ProductOut
from app.core.dependencies import get_current_admin

router = APIRouter(prefix="/admin", tags=["Admin"])


@router.get("/stats", response_model=AdminStatsOut)
async def get_admin_dashboard_stats(
    db: AsyncSession = Depends(get_db),
    admin_user: User = Depends(get_current_admin),
):
    """Aggregate platform-wide statistics for the admin control panel."""
    # Artisans
    artisan_count = (await db.execute(select(func.count(ArtisanProfile.id)))).scalar_one()
    approved_artisan_count = (
        await db.execute(select(func.count(ArtisanProfile.id)).where(ArtisanProfile.is_approved == True))
    ).scalar_one()

    # Products
    product_count = (await db.execute(select(func.count(Product.id)))).scalar_one()
    published_product_count = (
        await db.execute(select(func.count(Product.id)).where(Product.status == ProductStatus.published))
    ).scalar_one()

    # Orders & Revenue
    order_count = (await db.execute(select(func.count(Order.id)))).scalar_one()
    total_rev_res = (await db.execute(select(func.sum(Order.total)))).scalar_one()
    total_revenue = float(total_rev_res) if total_rev_res else 0.0

    # Inquiries
    inquiry_count = (await db.execute(select(func.count(Inquiry.id)))).scalar_one()

    return AdminStatsOut(
        total_artisans=artisan_count,
        approved_artisans=approved_artisan_count,
        pending_artisans=artisan_count - approved_artisan_count,
        total_products=product_count,
        published_products=published_product_count,
        total_orders=order_count,
        total_revenue=round(total_revenue, 2),
        total_inquiries=inquiry_count,
    )


@router.get("/artisans", response_model=list[ArtisanProfileOut])
async def list_artisans_for_moderation(
    is_approved: bool | None = Query(None, description="Filter by approval status"),
    db: AsyncSession = Depends(get_db),
    admin_user: User = Depends(get_current_admin),
):
    """List artisan registrations for review."""
    query = select(ArtisanProfile).options(selectinload(ArtisanProfile.user))
    if is_approved is not None:
        query = query.where(ArtisanProfile.is_approved == is_approved)
    query = query.order_by(ArtisanProfile.id.desc())
    result = await db.execute(query)
    return result.scalars().all()


@router.post("/artisans/{artisan_id}/approve", response_model=ArtisanProfileOut)
async def moderate_artisan(
    artisan_id: int,
    payload: ArtisanApprovalRequest,
    db: AsyncSession = Depends(get_db),
    admin_user: User = Depends(get_current_admin),
):
    """Approve or reject an artisan profile."""
    stmt = (
        select(ArtisanProfile)
        .where(ArtisanProfile.id == artisan_id)
        .options(selectinload(ArtisanProfile.user))
    )
    result = await db.execute(stmt)
    profile = result.scalar_one_or_none()

    if not profile:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Artisan not found")

    profile.is_approved = payload.is_approved
    if payload.is_approved:
        profile.approved_at = datetime.now(timezone.utc)
        profile.rejection_reason = None
    else:
        profile.rejection_reason = payload.rejection_reason

    await db.commit()
    await db.refresh(profile)
    return profile


@router.post("/products/{product_id}/status", response_model=ProductOut)
async def moderate_product(
    product_id: int,
    payload: ProductModerationRequest,
    db: AsyncSession = Depends(get_db),
    admin_user: User = Depends(get_current_admin),
):
    """Moderate or take down a product listing."""
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

    product.status = payload.status
    if payload.status == ProductStatus.published and not product.published_at:
        product.published_at = datetime.now(timezone.utc)

    await db.commit()
    await db.refresh(product)
    return product
