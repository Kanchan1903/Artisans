"""B2B Wholesale Inquiry router: wholesale lead generation and artisan inbox."""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.models.user import User
from app.models.artisan import ArtisanProfile
from app.models.product import Product
from app.models.inquiry import Inquiry
from app.models.notification import Notification
from app.schemas.inquiry import InquiryCreate, InquiryOut
from app.core.dependencies import get_current_artisan, get_optional_user
from app.utils.events import event_broker

router = APIRouter(prefix="/inquiries", tags=["Inquiries"])


@router.post("", response_model=InquiryOut, status_code=status.HTTP_201_CREATED)
async def create_inquiry(
    payload: InquiryCreate,
    current_user: User | None = Depends(get_optional_user),
    db: AsyncSession = Depends(get_db),
):
    """Buyer submits a B2B wholesale / custom order inquiry for an artisan's product."""
    stmt = (
        select(Product)
        .where(Product.id == payload.product_id)
        .options(selectinload(Product.artisan).selectinload(ArtisanProfile.user))
    )
    result = await db.execute(stmt)
    product = result.scalar_one_or_none()

    if not product:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")

    artisan_user = product.artisan.user if product.artisan else None
    target_lang = artisan_user.language.value if artisan_user else "hi"

    # Auto-translation stub / integration
    translated_text = payload.message
    if target_lang != "en":
        # Provide clean localized prefix for artisan comprehension
        translated_text = f"[{target_lang.upper()} Translation]: {payload.message}"

    inquiry = Inquiry(
        product_id=product.id,
        artisan_id=product.artisan_id,
        buyer_id=current_user.id if current_user else None,
        buyer_name=payload.buyer_name or (current_user.name if current_user else "Interested Buyer"),
        buyer_email=payload.buyer_email or (current_user.email if current_user else None),
        message_en=payload.message,
        message_translated=translated_text,
        is_b2b=payload.is_b2b,
        quantity_needed=payload.quantity_needed,
        is_read=False,
    )
    db.add(inquiry)
    await db.flush()

    # Notify artisan
    if artisan_user:
        notif = Notification(
            user_id=artisan_user.id,
            type="b2b_inquiry",
            title=f"New Bulk Inquiry for '{product.title_en}'",
            body=f"{inquiry.buyer_name} requested {inquiry.quantity_needed or 1} units: '{inquiry.message_en[:60]}...'",
            data={"inquiry_id": inquiry.id, "product_id": product.id},
        )
        db.add(notif)

    await db.commit()
    await db.refresh(inquiry)

    # Broadcast event
    await event_broker.publish(
        "inquiry_created",
        {
            "inquiry_id": inquiry.id,
            "product_id": product.id,
            "artisan_id": product.artisan_id,
            "quantity_needed": inquiry.quantity_needed,
        },
    )

    return InquiryOut(
        id=inquiry.id,
        product_id=inquiry.product_id,
        artisan_id=inquiry.artisan_id,
        buyer_id=inquiry.buyer_id,
        buyer_name=inquiry.buyer_name,
        buyer_email=inquiry.buyer_email,
        message_en=inquiry.message_en,
        message_translated=inquiry.message_translated,
        is_b2b=inquiry.is_b2b,
        quantity_needed=inquiry.quantity_needed,
        is_read=inquiry.is_read,
        created_at=inquiry.created_at,
        product_title=product.title_en,
    )


@router.get("/artisan/me", response_model=list[InquiryOut])
async def list_artisan_inquiries(
    artisan_tuple: tuple[User, ArtisanProfile] = Depends(get_current_artisan),
    db: AsyncSession = Depends(get_db),
):
    """Artisan view: all wholesale inquiries received for their handcrafted items."""
    user, profile = artisan_tuple
    stmt = (
        select(Inquiry)
        .where(Inquiry.artisan_id == profile.id)
        .options(selectinload(Inquiry.product))
        .order_by(Inquiry.id.desc())
    )
    result = await db.execute(stmt)
    inquiries = result.scalars().all()

    items = []
    for inq in inquiries:
        items.append(
            InquiryOut(
                id=inq.id,
                product_id=inq.product_id,
                artisan_id=inq.artisan_id,
                buyer_id=inq.buyer_id,
                buyer_name=inq.buyer_name,
                buyer_email=inq.buyer_email,
                message_en=inq.message_en,
                message_translated=inq.message_translated,
                is_b2b=inq.is_b2b,
                quantity_needed=inq.quantity_needed,
                is_read=inq.is_read,
                created_at=inq.created_at,
                product_title=inq.product.title_en if inq.product else None,
            )
        )
    return items


@router.patch("/{inquiry_id}/read", response_model=InquiryOut)
async def mark_inquiry_read(
    inquiry_id: int,
    artisan_tuple: tuple[User, ArtisanProfile] = Depends(get_current_artisan),
    db: AsyncSession = Depends(get_db),
):
    """Mark an inquiry as read by the artisan."""
    user, profile = artisan_tuple
    stmt = (
        select(Inquiry)
        .where(Inquiry.id == inquiry_id, Inquiry.artisan_id == profile.id)
        .options(selectinload(Inquiry.product))
    )
    result = await db.execute(stmt)
    inquiry = result.scalar_one_or_none()

    if not inquiry:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Inquiry not found")

    inquiry.is_read = True
    await db.commit()
    await db.refresh(inquiry)

    return InquiryOut(
        id=inquiry.id,
        product_id=inquiry.product_id,
        artisan_id=inquiry.artisan_id,
        buyer_id=inquiry.buyer_id,
        buyer_name=inquiry.buyer_name,
        buyer_email=inquiry.buyer_email,
        message_en=inquiry.message_en,
        message_translated=inquiry.message_translated,
        is_b2b=inquiry.is_b2b,
        quantity_needed=inquiry.quantity_needed,
        is_read=inquiry.is_read,
        created_at=inquiry.created_at,
        product_title=inquiry.product.title_en if inquiry.product else None,
    )
