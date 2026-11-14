"""B2B Wholesale Inquiry router: wholesale lead generation, artisan-controlled contact, and order workflow."""
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.models.user import User
from app.models.artisan import ArtisanProfile
from app.models.product import Product
from app.models.inquiry import Inquiry, InquiryStatus
from app.models.notification import Notification
from app.schemas.inquiry import InquiryCreate, InquiryStatusUpdate, InquiryOrderConfirm, InquiryOut
from app.core.dependencies import get_current_artisan, get_optional_user
from app.utils.events import event_broker

router = APIRouter(prefix="/inquiries", tags=["Inquiries"])


def _to_inquiry_out(inquiry: Inquiry, product: Product | None = None) -> InquiryOut:
    p = product or inquiry.product
    img_url = p.images[0].url if (p and p.images) else None
    return InquiryOut(
        id=inquiry.id,
        product_id=inquiry.product_id,
        artisan_id=inquiry.artisan_id,
        buyer_id=inquiry.buyer_id,
        buyer_name=inquiry.buyer_name,
        buyer_email=inquiry.buyer_email,
        buyer_phone=inquiry.buyer_phone,
        message_en=inquiry.message_en,
        message_translated=inquiry.message_translated,
        is_b2b=inquiry.is_b2b,
        quantity_needed=inquiry.quantity_needed,
        is_read=inquiry.is_read,
        created_at=inquiry.created_at,
        product_title=p.title_en if p else None,
        product_image_url=img_url,
        status=inquiry.status or "new",
        scheduled_contact_at=inquiry.scheduled_contact_at,
        contact_notes=inquiry.contact_notes,
        artisan_response=inquiry.artisan_response,
        agreed_price=inquiry.agreed_price,
        agreed_quantity=inquiry.agreed_quantity,
        delivery_details=inquiry.delivery_details,
        confirmed_at=inquiry.confirmed_at,
        completed_at=inquiry.completed_at,
    )


@router.post("", response_model=InquiryOut, status_code=status.HTTP_201_CREATED)
async def create_inquiry(
    payload: InquiryCreate,
    current_user: User | None = Depends(get_optional_user),
    db: AsyncSession = Depends(get_db),
):
    """Buyer submits an inquiry/order request for an artisan's handcrafted creation."""
    stmt = (
        select(Product)
        .where(Product.id == payload.product_id)
        .options(
            selectinload(Product.images),
            selectinload(Product.artisan).selectinload(ArtisanProfile.user),
        )
    )
    result = await db.execute(stmt)
    product = result.scalar_one_or_none()

    if not product:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")

    # Check product availability
    prod_status_val = str(product.status.value if hasattr(product.status, "value") else product.status)
    if prod_status_val != "published":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Product is not currently available for inquiry")

    if getattr(product, "stock", 0) <= 0:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Product is currently out of stock / unavailable")

    # Prevent duplicate identical pending inquiry from the same contact within 5 minutes
    contact_phone = payload.buyer_phone or (current_user.phone if current_user else None)
    contact_email = payload.buyer_email or (current_user.email if current_user else None)
    if contact_phone or contact_email:
        dup_stmt = (
            select(Inquiry)
            .where(
                Inquiry.product_id == product.id,
                Inquiry.status.in_(["new", "contact_later", "contact_scheduled"]),
            )
            .order_by(Inquiry.id.desc())
        )
        dup_res = await db.execute(dup_stmt)
        recent_inq = dup_res.scalars().first()
        if (
            recent_inq
            and (
                (contact_phone and recent_inq.buyer_phone == contact_phone)
                or (contact_email and recent_inq.buyer_email == contact_email)
            )
            and recent_inq.message_en == payload.message
        ):
            return _to_inquiry_out(recent_inq, product)

    artisan_user = product.artisan.user if product.artisan else None
    target_lang = artisan_user.language.value if artisan_user else "hi"

    # Auto-translation stub / integration
    translated_text = payload.message
    if target_lang != "en":
        translated_text = f"[{target_lang.upper()} Translation]: {payload.message}"

    inquiry = Inquiry(
        product_id=product.id,
        artisan_id=product.artisan_id,
        buyer_id=current_user.id if current_user else None,
        buyer_name=payload.buyer_name or (current_user.name if current_user else "Interested Buyer"),
        buyer_email=contact_email,
        buyer_phone=contact_phone,
        message_en=payload.message,
        message_translated=translated_text,
        is_b2b=payload.is_b2b,
        quantity_needed=payload.quantity_needed,
        is_read=False,
        status="new",
    )
    db.add(inquiry)
    await db.flush()

    # Instant notification to artisan
    if artisan_user:
        notif = Notification(
            user_id=artisan_user.id,
            type="b2b_inquiry",
            title=f"New inquiry received for {product.title_en}!",
            body=f"{inquiry.buyer_name} ({inquiry.buyer_phone or inquiry.buyer_email or 'Buyer'}) requested {inquiry.quantity_needed or 1} units: '{inquiry.message_en[:60]}...'",
            data={"inquiry_id": inquiry.id, "product_id": product.id},
        )
        db.add(notif)

    # Optional notification to buyer if registered user
    if current_user and current_user.id != (artisan_user.id if artisan_user else None):
        buyer_notif = Notification(
            user_id=current_user.id,
            type="inquiry_submitted",
            title="Inquiry received by KalaSathi Artisan",
            body=f"Your inquiry for '{product.title_en}' has been forwarded to artisan {artisan_user.name if artisan_user else 'maker'}.",
            data={"inquiry_id": inquiry.id, "product_id": product.id},
        )
        db.add(buyer_notif)

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

    return _to_inquiry_out(inquiry, product)


@router.get("/artisan/me", response_model=list[InquiryOut])
async def list_artisan_inquiries(
    status_filter: str | None = Query(None, description="Filter by status: new, accepted, contact_scheduled, contacted, negotiation, order_confirmed, completed, rejected, contact_later"),
    artisan_tuple: tuple[User, ArtisanProfile] = Depends(get_current_artisan),
    db: AsyncSession = Depends(get_db),
):
    """Artisan view: all buyer inquiries and order requests received."""
    user, profile = artisan_tuple
    stmt = (
        select(Inquiry)
        .where(Inquiry.artisan_id == profile.id)
        .options(selectinload(Inquiry.product).selectinload(Product.images))
        .order_by(Inquiry.id.desc())
    )
    if status_filter:
        stmt = stmt.where(Inquiry.status == status_filter)

    result = await db.execute(stmt)
    inquiries = result.scalars().all()
    return [_to_inquiry_out(inq) for inq in inquiries]


@router.patch("/{inquiry_id}/status", response_model=InquiryOut)
async def update_inquiry_status(
    inquiry_id: int,
    payload: InquiryStatusUpdate,
    artisan_tuple: tuple[User, ArtisanProfile] = Depends(get_current_artisan),
    db: AsyncSession = Depends(get_db),
):
    """Artisan updates inquiry status (Accept, Reject, Contact Later, Schedule Contact, Negotiation, etc.)."""
    user, profile = artisan_tuple
    stmt = (
        select(Inquiry)
        .where(Inquiry.id == inquiry_id, Inquiry.artisan_id == profile.id)
        .options(selectinload(Inquiry.product).selectinload(Product.images))
    )
    result = await db.execute(stmt)
    inquiry = result.scalar_one_or_none()

    if not inquiry:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Inquiry not found")

    inquiry.status = payload.status
    inquiry.is_read = True

    if payload.scheduled_contact_at is not None:
        inquiry.scheduled_contact_at = payload.scheduled_contact_at
    if payload.contact_notes is not None:
        inquiry.contact_notes = payload.contact_notes
    if payload.artisan_response is not None:
        inquiry.artisan_response = payload.artisan_response

    # If artisan accepted or responded and buyer is registered, notify buyer
    if inquiry.buyer_id and payload.status in ["accepted", "contacted", "rejected"]:
        buyer_stmt = select(User).where(User.id == inquiry.buyer_id)
        buyer_res = await db.execute(buyer_stmt)
        buyer_user = buyer_res.scalar_one_or_none()
        if buyer_user:
            prod_name = inquiry.product.title_en if inquiry.product else "handcrafted creation"
            notif_title = f"Artisan update on '{prod_name}'"
            notif_body = f"Artisan has marked your inquiry as {payload.status.replace('_', ' ').capitalize()}."
            if payload.artisan_response:
                notif_body = f"Message from artisan: {payload.artisan_response}"
            db.add(Notification(
                user_id=buyer_user.id,
                type="inquiry_status_updated",
                title=notif_title,
                body=notif_body,
                data={"inquiry_id": inquiry.id, "status": payload.status},
            ))

    await db.commit()
    await db.refresh(inquiry)
    return _to_inquiry_out(inquiry)


@router.post("/{inquiry_id}/confirm-order", response_model=InquiryOut)
async def confirm_inquiry_order(
    inquiry_id: int,
    payload: InquiryOrderConfirm,
    artisan_tuple: tuple[User, ArtisanProfile] = Depends(get_current_artisan),
    db: AsyncSession = Depends(get_db),
):
    """Artisan confirms an agreed order with final price, quantity, and delivery terms."""
    user, profile = artisan_tuple
    stmt = (
        select(Inquiry)
        .where(Inquiry.id == inquiry_id, Inquiry.artisan_id == profile.id)
        .options(selectinload(Inquiry.product).selectinload(Product.images))
    )
    result = await db.execute(stmt)
    inquiry = result.scalar_one_or_none()

    if not inquiry:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Inquiry not found")

    inquiry.status = InquiryStatus.order_confirmed.value
    inquiry.agreed_price = payload.agreed_price
    inquiry.agreed_quantity = payload.agreed_quantity
    inquiry.delivery_details = payload.delivery_details
    inquiry.confirmed_at = datetime.now(timezone.utc)
    if payload.contact_notes:
        inquiry.contact_notes = payload.contact_notes

    # Deduct stock if sufficient stock exists
    if inquiry.product and inquiry.product.stock is not None:
        if inquiry.product.stock >= payload.agreed_quantity:
            inquiry.product.stock -= payload.agreed_quantity

    # Notify buyer if registered
    if inquiry.buyer_id:
        prod_title = inquiry.product.title_en if inquiry.product else "item"
        db.add(Notification(
            user_id=inquiry.buyer_id,
            type="order_confirmed",
            title=f"Order Confirmed: {prod_title}",
            body=f"Your order for {payload.agreed_quantity} unit(s) has been confirmed at ₹{payload.agreed_price}. Delivery details: {payload.delivery_details}",
            data={"inquiry_id": inquiry.id, "agreed_price": payload.agreed_price, "quantity": payload.agreed_quantity},
        ))

    await db.commit()
    await db.refresh(inquiry)
    return _to_inquiry_out(inquiry)


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
        .options(selectinload(Inquiry.product).selectinload(Product.images))
    )
    result = await db.execute(stmt)
    inquiry = result.scalar_one_or_none()

    if not inquiry:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Inquiry not found")

    inquiry.is_read = True
    await db.commit()
    await db.refresh(inquiry)
    return _to_inquiry_out(inquiry)
