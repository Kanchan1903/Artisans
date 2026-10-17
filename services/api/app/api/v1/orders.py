"""Order router: Checkout, artisan order fulfillment, status updates, notifications, and webhooks."""
from datetime import datetime, timezone
from collections import defaultdict
from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.models.user import User
from app.models.artisan import ArtisanProfile
from app.models.product import Product
from app.models.order import Order, OrderItem, OrderStatus, PaymentMethod
from app.models.earning import Earning, EarningStatus
from app.models.notification import Notification
from app.schemas.order import OrderCreate, OrderOut, OrderItemOut, OrderStatusUpdate
from app.core.dependencies import get_current_user, get_current_artisan
from app.utils.events import event_broker

router = APIRouter(prefix="/orders", tags=["Orders"])


@router.post("", response_model=OrderOut, status_code=status.HTTP_201_CREATED)
async def create_order(
    payload: OrderCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Buyer creates an order via website checkout (Razorpay test mode or Cash on Delivery).
    - Idempotent: suppresses duplicate sales on network retries or repeated payment events.
    - Multi-artisan: partitions items and notifies each distinct artisan with their specific item subtotal.
    - Decrements inventory stock accurately.
    """
    if not payload.items:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Order items cannot be empty")

    # 1. Idempotency Check (by payment_id)
    if payload.payment_id:
        existing_stmt = (
            select(Order)
            .where(Order.payment_id == payload.payment_id)
            .options(
                selectinload(Order.items).selectinload(OrderItem.product).selectinload(Product.images),
            )
        )
        existing_res = await db.execute(existing_stmt)
        existing_order = existing_res.scalar_one_or_none()
        if existing_order:
            return _format_order_out(existing_order)

    total_amount = 0.0
    order_items_to_create = []
    affected_artisans = set()

    # 2. Stock Verification & Item Preparation
    for item_data in payload.items:
        stmt = select(Product).where(Product.id == item_data.product_id).options(selectinload(Product.images))
        result = await db.execute(stmt)
        product = result.scalar_one_or_none()

        if not product:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Product #{item_data.product_id} not found",
            )
        if product.stock < item_data.quantity:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Insufficient stock for product '{product.title_en}'. Available: {product.stock}",
            )

        # Decrement stock
        product.stock -= item_data.quantity

        line_total = product.price * item_data.quantity
        total_amount += line_total
        affected_artisans.add(product.artisan_id)

        order_items_to_create.append(
            {
                "product": product,
                "quantity": item_data.quantity,
                "unit_price": product.price,
                "artisan_id": product.artisan_id,
            }
        )

    # 3. Determine Payment State
    if payload.payment_method == PaymentMethod.cod:
        initial_payment_status = "cod_pending"
    else:
        initial_payment_status = "paid" if payload.payment_id else "unpaid"

    order = Order(
        buyer_id=current_user.id,
        status=OrderStatus.pending,
        total=round(total_amount, 2),
        shipping_address=payload.shipping_address.model_dump(),
        payment_method=payload.payment_method,
        payment_id=payload.payment_id,
        payment_status=initial_payment_status,
        notes=payload.notes,
    )
    db.add(order)
    await db.flush()

    # 4. Create OrderItems and Pending Earnings
    for item in order_items_to_create:
        prod = item["product"]
        order_item = OrderItem(
            order_id=order.id,
            product_id=prod.id,
            artisan_id=item["artisan_id"],
            quantity=item["quantity"],
            unit_price=item["unit_price"],
        )
        db.add(order_item)
        await db.flush()

        # Net earning = unit_price * quantity * 0.92 (covers 8% platform fee deduction)
        net_amount = round(item["unit_price"] * item["quantity"] * 0.92, 2)
        earning = Earning(
            artisan_id=item["artisan_id"],
            order_item_id=order_item.id,
            amount=net_amount,
            status=EarningStatus.pending,
        )
        db.add(earning)

    # 5. Multi-Artisan Handling: Group items per artisan to send 1 clean consolidated notification
    artisan_items_map = defaultdict(list)
    for item in order_items_to_create:
        artisan_items_map[item["artisan_id"]].append(item)

    for artisan_id, items in artisan_items_map.items():
        artisan_stmt = select(ArtisanProfile).where(ArtisanProfile.id == artisan_id)
        artisan_res = await db.execute(artisan_stmt)
        artisan_profile = artisan_res.scalar_one_or_none()

        if artisan_profile:
            subtotal = sum(i["unit_price"] * i["quantity"] for i in items)
            net_earning = round(subtotal * 0.92, 2)
            item_summaries = ", ".join(f"{i['quantity']}x {i['product'].title_en}" for i in items)

            notif = Notification(
                user_id=artisan_profile.user_id,
                type="new_order",
                title=f"New Order #{order.id} Received!",
                body=f"Buyer ordered {item_summaries}. Net earning: ₹{net_earning:.0f} (Shipping to {payload.shipping_address.city}).",
                data={
                    "order_id": order.id,
                    "artisan_id": artisan_id,
                    "gross_amount": subtotal,
                    "net_amount": net_earning,
                    "items_count": len(items),
                    "shipping_city": payload.shipping_address.city,
                    "payment_status": initial_payment_status,
                },
            )
            db.add(notif)

    await db.commit()

    # Load complete order
    stmt = (
        select(Order)
        .where(Order.id == order.id)
        .options(
            selectinload(Order.items).selectinload(OrderItem.product).selectinload(Product.images),
        )
    )
    result = await db.execute(stmt)
    full_order = result.scalar_one()

    # Broadcast real-time SSE event to notify artisan app
    await event_broker.publish(
        "order_created",
        {
            "order_id": full_order.id,
            "total": full_order.total,
            "shipping_city": payload.shipping_address.city,
            "artisan_ids": list(affected_artisans),
            "buyer_name": payload.shipping_address.name,
        },
    )

    return _format_order_out(full_order)


@router.get("", response_model=list[OrderOut])
async def list_buyer_orders(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get all orders placed by the current user."""
    stmt = (
        select(Order)
        .where(Order.buyer_id == current_user.id)
        .options(
            selectinload(Order.items).selectinload(OrderItem.product).selectinload(Product.images),
        )
        .order_by(Order.id.desc())
    )
    result = await db.execute(stmt)
    orders = result.scalars().all()
    return [_format_order_out(o) for o in orders]


@router.get("/artisan/me", response_model=list[OrderOut])
async def list_artisan_orders(
    artisan_tuple: tuple[User, ArtisanProfile] = Depends(get_current_artisan),
    db: AsyncSession = Depends(get_db),
):
    """Artisan view: get incoming orders containing products crafted by this artisan with strict authorization."""
    user, profile = artisan_tuple
    stmt = (
        select(Order)
        .join(Order.items)
        .where(OrderItem.artisan_id == profile.id)
        .distinct()
        .options(
            selectinload(Order.items).selectinload(OrderItem.product).selectinload(Product.images),
        )
        .order_by(Order.id.desc())
    )
    result = await db.execute(stmt)
    orders = result.scalars().all()
    return [_format_order_out(o, filter_artisan_id=profile.id) for o in orders]


@router.get("/{order_id}", response_model=OrderOut)
async def get_order_detail(
    order_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get tracking details for a specific order."""
    stmt = (
        select(Order)
        .where(Order.id == order_id)
        .options(
            selectinload(Order.items).selectinload(OrderItem.product).selectinload(Product.images),
        )
    )
    result = await db.execute(stmt)
    order = result.scalar_one_or_none()

    if not order:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found")

    return _format_order_out(order)


@router.patch("/{order_id}/status", response_model=OrderOut)
async def update_order_status(
    order_id: int,
    payload: OrderStatusUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Update order status (Accepted, Packed, Shipped, Delivered, Cancelled). Settle earnings on delivery, void on cancellation."""
    stmt = (
        select(Order)
        .where(Order.id == order_id)
        .options(
            selectinload(Order.items).selectinload(OrderItem.product).selectinload(Product.images),
            selectinload(Order.items).selectinload(OrderItem.earning),
        )
    )
    result = await db.execute(stmt)
    order = result.scalar_one_or_none()

    if not order:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found")

    order.status = payload.status

    # 1. Delivery Settlement: Upon delivery, settle earnings and update COD payment state
    if payload.status == OrderStatus.delivered:
        now = datetime.now(timezone.utc)
        if order.payment_method == PaymentMethod.cod:
            order.payment_status = "paid"
        for item in order.items:
            if item.earning:
                item.earning.status = EarningStatus.settled
                item.earning.settled_at = now

    # 2. Cancellation: Void earnings and restock inventory
    elif payload.status == OrderStatus.cancelled:
        if order.payment_status == "paid":
            order.payment_status = "refunded"
        for item in order.items:
            if item.earning:
                item.earning.status = EarningStatus.cancelled
            if item.product:
                item.product.stock += item.quantity

    # Add buyer notification
    notif = Notification(
        user_id=order.buyer_id,
        type="order_status",
        title=f"Order #{order.id} {payload.status.value.capitalize()}!",
        body=f"Your KalaSathi order has been updated to '{payload.status.value}'.",
        data={"order_id": order.id, "status": payload.status.value},
    )
    db.add(notif)

    await db.commit()

    refetch_stmt = (
        select(Order)
        .where(Order.id == order.id)
        .options(
            selectinload(Order.items).selectinload(OrderItem.product).selectinload(Product.images),
        )
    )
    refetch_res = await db.execute(refetch_stmt)
    fresh_order = refetch_res.scalar_one()

    # Broadcast event
    await event_broker.publish(
        "order_status_updated",
        {
            "order_id": fresh_order.id,
            "status": payload.status.value,
            "buyer_id": fresh_order.buyer_id,
        },
    )

    return _format_order_out(fresh_order)


@router.post("/{order_id}/cancel", response_model=OrderOut)
async def cancel_order(
    order_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Explicitly cancel an order, void earnings, and restore inventory stock."""
    return await update_order_status(
        order_id=order_id,
        payload=OrderStatusUpdate(status=OrderStatus.cancelled),
        current_user=current_user,
        db=db,
    )


@router.post("/{order_id}/pay", response_model=OrderOut)
async def mark_order_paid(
    order_id: int,
    payment_id: str,
    db: AsyncSession = Depends(get_db),
):
    """Marks an order as paid idempotently."""
    stmt = (
        select(Order)
        .where(Order.id == order_id)
        .options(
            selectinload(Order.items).selectinload(OrderItem.product).selectinload(Product.images),
        )
    )
    res = await db.execute(stmt)
    order = res.scalar_one_or_none()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    if order.payment_status == "paid":
        return _format_order_out(order)  # Idempotent: already paid

    order.payment_status = "paid"
    order.payment_id = payment_id
    await db.commit()
    await db.refresh(order)
    return _format_order_out(order)


@router.post("/webhook")
async def payment_webhook(
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    """Idempotent payment webhook for Razorpay or payment gateways: suppresses duplicate events."""
    try:
        body = await request.json()
    except Exception:
        return {"status": "ignored"}

    payment_id = body.get("payment_id") or body.get("id") or body.get("payload", {}).get("payment", {}).get("entity", {}).get("id")
    order_id = body.get("order_id")

    if not payment_id and not order_id:
        return {"status": "ok", "message": "Ignored unhandled webhook payload"}

    if order_id:
        stmt = select(Order).where(Order.id == int(order_id))
        res = await db.execute(stmt)
        order = res.scalar_one_or_none()
        if order:
            if order.payment_status == "paid":
                return {"status": "already_processed"}
            order.payment_status = "paid"
            if payment_id:
                order.payment_id = str(payment_id)
            await db.commit()
            return {"status": "processed", "order_id": order.id}

    return {"status": "ok"}


def _format_order_out(order: Order, filter_artisan_id: int | None = None) -> OrderOut:
    items_out = []
    subtotal = 0.0
    for item in order.items:
        if filter_artisan_id is not None and item.artisan_id != filter_artisan_id:
            continue
        subtotal += item.unit_price * item.quantity
        img_url = item.product.images[0].url if item.product and item.product.images else None
        items_out.append(
            OrderItemOut(
                id=item.id,
                product_id=item.product_id,
                artisan_id=item.artisan_id,
                quantity=item.quantity,
                unit_price=item.unit_price,
                product_title=item.product.title_en if item.product else None,
                product_image_url=img_url,
            )
        )

    display_total = subtotal if filter_artisan_id is not None else order.total

    return OrderOut(
        id=order.id,
        buyer_id=order.buyer_id,
        status=order.status,
        total=display_total,
        shipping_address=order.shipping_address,
        payment_method=order.payment_method,
        payment_id=order.payment_id,
        payment_status=getattr(order, "payment_status", "paid" if order.payment_id else "cod_pending"),
        notes=order.notes,
        created_at=order.created_at,
        updated_at=order.updated_at,
        items=items_out,
    )
