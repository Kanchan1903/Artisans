"""Wishlist router — buyer saves/unsaves products."""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.models.user import User
from app.models.product import Product, ProductImage, ProductTranslation, Category
from app.models.artisan import ArtisanProfile
from app.models.wishlist import WishlistItem
from app.schemas.wishlist import WishlistItemOut, WishlistToggleOut
from app.core.dependencies import get_current_user

router = APIRouter(prefix="/wishlist", tags=["Wishlist"])


@router.get("", response_model=list[WishlistItemOut])
async def get_my_wishlist(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get all wishlist items for the current buyer."""
    stmt = (
        select(WishlistItem)
        .where(WishlistItem.user_id == current_user.id)
        .options(
            selectinload(WishlistItem.product).selectinload(Product.images),
            selectinload(WishlistItem.product).selectinload(Product.translations),
            selectinload(WishlistItem.product).selectinload(Product.category),
            selectinload(WishlistItem.product).selectinload(Product.artisan).selectinload(ArtisanProfile.user),
        )
        .order_by(WishlistItem.id.desc())
    )
    result = await db.execute(stmt)
    return result.scalars().all()


@router.post("/{product_id}", response_model=WishlistToggleOut)
async def toggle_wishlist(
    product_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Toggle a product in/out of the buyer's wishlist."""
    # Verify product exists
    product_stmt = select(Product).where(Product.id == product_id)
    result = await db.execute(product_stmt)
    product = result.scalar_one_or_none()
    if not product:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")

    # Check if already wishlisted
    existing_stmt = select(WishlistItem).where(
        WishlistItem.user_id == current_user.id,
        WishlistItem.product_id == product_id,
    )
    existing_res = await db.execute(existing_stmt)
    existing = existing_res.scalar_one_or_none()

    if existing:
        await db.delete(existing)
        await db.commit()
        return WishlistToggleOut(wishlisted=False, message="Removed from wishlist")
    else:
        item = WishlistItem(user_id=current_user.id, product_id=product_id)
        db.add(item)
        await db.commit()
        return WishlistToggleOut(wishlisted=True, message="Added to wishlist")


@router.get("/check/{product_id}")
async def check_wishlist(
    product_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Check if a specific product is in the buyer's wishlist."""
    stmt = select(WishlistItem).where(
        WishlistItem.user_id == current_user.id,
        WishlistItem.product_id == product_id,
    )
    result = await db.execute(stmt)
    existing = result.scalar_one_or_none()
    return {"wishlisted": existing is not None}
