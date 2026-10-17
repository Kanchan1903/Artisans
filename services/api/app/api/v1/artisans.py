"""Artisan router: Onboarding, profile management, and public artisan directory."""
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.models.user import User
from app.models.artisan import ArtisanProfile
from app.models.product import Product, ProductStatus
from app.schemas.artisan import (
    ArtisanProfileOut,
    ArtisanProfileUpdate,
    ArtisanPublicOut,
)
from app.core.dependencies import get_current_artisan

router = APIRouter(prefix="/artisans", tags=["Artisans"])


@router.get("/me", response_model=ArtisanProfileOut)
async def get_my_artisan_profile(
    artisan_tuple: tuple[User, ArtisanProfile] = Depends(get_current_artisan),
    db: AsyncSession = Depends(get_db),
):
    """Retrieve the current authenticated artisan's profile."""
    user, profile = artisan_tuple
    stmt = (
        select(ArtisanProfile)
        .where(ArtisanProfile.id == profile.id)
        .options(selectinload(ArtisanProfile.user))
    )
    result = await db.execute(stmt)
    return result.scalar_one()


@router.put("/me", response_model=ArtisanProfileOut)
async def update_my_artisan_profile(
    payload: ArtisanProfileUpdate,
    artisan_tuple: tuple[User, ArtisanProfile] = Depends(get_current_artisan),
    db: AsyncSession = Depends(get_db),
):
    """Update craft profile, bio, regional location, and banking/UPI info."""
    user, profile = artisan_tuple

    update_data = payload.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(profile, field, value)

    await db.commit()
    await db.refresh(profile)

    stmt = (
        select(ArtisanProfile)
        .where(ArtisanProfile.id == profile.id)
        .options(selectinload(ArtisanProfile.user))
    )
    result = await db.execute(stmt)
    return result.scalar_one()


@router.get("", response_model=list[ArtisanPublicOut])
async def list_public_artisans(
    craft_type: str | None = Query(None, description="Filter by craft category/type"),
    state: str | None = Query(None, description="Filter by Indian state"),
    limit: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
):
    """Public directory of approved Indian artisans for web buyers."""
    query = (
        select(ArtisanProfile)
        .where(ArtisanProfile.is_approved == True)
        .options(selectinload(ArtisanProfile.user), selectinload(ArtisanProfile.products))
    )

    if craft_type:
        query = query.where(ArtisanProfile.craft_type.ilike(f"%{craft_type}%"))
    if state:
        query = query.where(ArtisanProfile.state.ilike(f"%{state}%"))

    query = query.order_by(ArtisanProfile.id.desc()).limit(limit)
    result = await db.execute(query)
    profiles = result.scalars().all()

    items = []
    for p in profiles:
        published_count = sum(1 for prod in p.products if prod.status == ProductStatus.published)
        items.append(
            ArtisanPublicOut(
                id=p.id,
                user_id=p.user_id,
                name=p.user.name if p.user else f"Artisan #{p.id}",
                craft_type=p.craft_type,
                village=p.village,
                district=p.district,
                state=p.state,
                bio=p.bio,
                bio_hi=p.bio_hi,
                bio_mr=p.bio_mr,
                profile_photo_url=p.profile_photo_url,
                years_experience=p.years_experience,
                is_approved=p.is_approved,
                product_count=published_count,
            )
        )
    return items


@router.get("/{artisan_id}", response_model=ArtisanPublicOut)
async def get_public_artisan_detail(
    artisan_id: int,
    db: AsyncSession = Depends(get_db),
):
    """Get public artisan profile with story and product count."""
    stmt = (
        select(ArtisanProfile)
        .where(ArtisanProfile.id == artisan_id)
        .options(selectinload(ArtisanProfile.user), selectinload(ArtisanProfile.products))
    )
    result = await db.execute(stmt)
    profile = result.scalar_one_or_none()

    if not profile:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Artisan not found")

    published_count = sum(1 for prod in profile.products if prod.status == ProductStatus.published)
    return ArtisanPublicOut(
        id=profile.id,
        user_id=profile.user_id,
        name=profile.user.name if profile.user else f"Artisan #{profile.id}",
        craft_type=profile.craft_type,
        village=profile.village,
        district=profile.district,
        state=profile.state,
        bio=profile.bio,
        bio_hi=profile.bio_hi,
        bio_mr=profile.bio_mr,
        profile_photo_url=profile.profile_photo_url,
        years_experience=profile.years_experience,
        is_approved=profile.is_approved,
        product_count=published_count,
    )
