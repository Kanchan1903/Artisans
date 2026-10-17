"""Artisan Earnings router: balance tracking, settlements, and professional dashboard metrics."""
from collections import defaultdict
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.models.user import User
from app.models.artisan import ArtisanProfile
from app.models.order import Order, OrderItem, OrderStatus
from app.models.product import Product
from app.models.earning import Earning, EarningStatus
from app.schemas.earning import (
    EarningsSummaryOut,
    MonthlyEarning,
    ArtisanDashboardOut,
    SalesTrendItem,
    BestSellingProduct,
    DashboardOrderSummary,
)
from app.core.dependencies import get_current_artisan

router = APIRouter(prefix="/earnings", tags=["Earnings"])


@router.get("/summary", response_model=EarningsSummaryOut)
async def get_artisan_earnings_summary(
    artisan_tuple: tuple[User, ArtisanProfile] = Depends(get_current_artisan),
    db: AsyncSession = Depends(get_db),
):
    """Retrieve financial summary for current artisan: total, settled, pending, and monthly metrics."""
    user, profile = artisan_tuple
    stmt = (
        select(Earning)
        .where(Earning.artisan_id == profile.id, Earning.status != EarningStatus.cancelled)
        .order_by(Earning.created_at.desc())
    )
    result = await db.execute(stmt)
    earnings = result.scalars().all()

    total = 0.0
    settled = 0.0
    pending = 0.0
    fulfilled_orders = 0
    monthly_map = defaultdict(lambda: {"amount": 0.0, "count": 0})

    for e in earnings:
        total += e.amount
        if e.status == EarningStatus.settled:
            settled += e.amount
            fulfilled_orders += 1
        else:
            pending += e.amount

        month_str = e.created_at.strftime("%Y-%m") if e.created_at else "Current"
        monthly_map[month_str]["amount"] += e.amount
        monthly_map[month_str]["count"] += 1

    monthly_breakdown = [
        MonthlyEarning(month=m, amount=round(data["amount"], 2), order_count=data["count"])
        for m, data in sorted(monthly_map.items(), reverse=True)
    ]

    return EarningsSummaryOut(
        total_earnings=round(total, 2),
        settled_earnings=round(settled, 2),
        pending_earnings=round(pending, 2),
        total_orders_fulfilled=fulfilled_orders,
        monthly_breakdown=monthly_breakdown,
    )


@router.get("/dashboard", response_model=ArtisanDashboardOut)
async def get_artisan_dashboard(
    artisan_tuple: tuple[User, ArtisanProfile] = Depends(get_current_artisan),
    db: AsyncSession = Depends(get_db),
):
    """
    Generates a professional financial dashboard strictly calculated from actual database records:
    - Gross sales vs. net earnings (with transparent 8% platform fee deductions)
    - Distinguishes order value, net earnings, settled payouts, and pending payouts
    - Excludes cancelled/unpaid orders from completed revenue; tracks refunds/cancellations
    - Daily, weekly, and monthly sales trends
    - Best-selling products ranked by units sold and revenue
    - Order history and fulfillment statuses
    - Enforces strict artisan role-based authorization
    """
    user, profile = artisan_tuple

    # 1. Fetch all OrderItems for this artisan with eager loaded Order, Product, and Earning
    stmt = (
        select(OrderItem)
        .where(OrderItem.artisan_id == profile.id)
        .options(
            selectinload(OrderItem.order),
            selectinload(OrderItem.product).selectinload(Product.images),
            selectinload(OrderItem.earning),
        )
        .order_by(OrderItem.id.desc())
    )
    result = await db.execute(stmt)
    order_items = result.scalars().all()

    # Metrics accumulators
    valid_order_ids = set()
    total_products_sold = 0
    gross_sales = 0.0
    refunds_cancellations = 0.0
    settled_payout = 0.0

    daily_map = defaultdict(lambda: {"gross": 0.0, "net": 0.0, "orders": set()})
    weekly_map = defaultdict(lambda: {"gross": 0.0, "net": 0.0, "orders": set()})
    monthly_map = defaultdict(lambda: {"gross": 0.0, "net": 0.0, "orders": set()})
    product_sales_map = defaultdict(lambda: {"qty": 0, "gross": 0.0, "title": "", "image_url": None})
    recent_orders_list: list[DashboardOrderSummary] = []
    seen_order_in_recent = set()

    for oi in order_items:
        order = oi.order
        if not order:
            continue

        item_gross = round(oi.unit_price * oi.quantity, 2)
        item_net = round(item_gross * 0.92, 2)  # Net of 8% platform fee
        order_date = order.created_at

        # 2. Handle Cancelled Orders: Track under refunds/cancellations and do NOT count as revenue
        if order.status == OrderStatus.cancelled:
            refunds_cancellations += item_gross
            continue

        # 3. Handle Unpaid Orders: Exclude from completed revenue
        if getattr(order, "payment_status", "unpaid") == "unpaid":
            continue

        # Valid Revenue Generating Items
        valid_order_ids.add(order.id)
        total_products_sold += oi.quantity
        gross_sales += item_gross

        # Payout status
        if (oi.earning and oi.earning.status == EarningStatus.settled) or order.status == OrderStatus.delivered:
            settled_payout += (oi.earning.amount if oi.earning else item_net)

        # Sales Trends
        if order_date:
            day_str = order_date.strftime("%Y-%m-%d")
            week_str = order_date.strftime("%Y-W%U")
            month_str = order_date.strftime("%Y-%m")

            daily_map[day_str]["gross"] += item_gross
            daily_map[day_str]["net"] += item_net
            daily_map[day_str]["orders"].add(order.id)

            weekly_map[week_str]["gross"] += item_gross
            weekly_map[week_str]["net"] += item_net
            weekly_map[week_str]["orders"].add(order.id)

            monthly_map[month_str]["gross"] += item_gross
            monthly_map[month_str]["net"] += item_net
            monthly_map[month_str]["orders"].add(order.id)

        # Best Selling Products
        prod_title = oi.product.title_en if oi.product else f"Product #{oi.product_id}"
        img_url = oi.product.images[0].url if oi.product and oi.product.images else None
        product_sales_map[oi.product_id]["qty"] += oi.quantity
        product_sales_map[oi.product_id]["gross"] += item_gross
        product_sales_map[oi.product_id]["title"] = prod_title
        if img_url:
            product_sales_map[oi.product_id]["image_url"] = img_url

        # Recent Orders Summary (up to 10 distinct orders)
        if order.id not in seen_order_in_recent and len(recent_orders_list) < 10:
            seen_order_in_recent.add(order.id)
            shipping_city = order.shipping_address.get("city", "India") if order.shipping_address else "India"
            recent_orders_list.append(
                DashboardOrderSummary(
                    order_id=order.id,
                    created_at=order.created_at,
                    status=order.status.value,
                    payment_method=order.payment_method.value,
                    shipping_city=shipping_city,
                    total_amount=round(item_gross, 2),
                    artisan_net_earnings=round(item_net, 2),
                    quantity=oi.quantity,
                    product_title=prod_title,
                )
            )

    # Derived Totals
    gross_sales = round(gross_sales, 2)
    platform_fees = round(gross_sales * 0.08, 2)
    net_earnings = round(gross_sales - platform_fees, 2)
    settled_payout = round(settled_payout, 2)
    pending_payout = round(max(0.0, net_earnings - settled_payout), 2)
    refunds_cancellations = round(refunds_cancellations, 2)

    # Format trends
    daily_trends = [
        SalesTrendItem(
            period=period,
            gross_sales=round(data["gross"], 2),
            net_earnings=round(data["net"], 2),
            order_count=len(data["orders"]),
        )
        for period, data in sorted(daily_map.items(), reverse=True)[:14]
    ]

    weekly_trends = [
        SalesTrendItem(
            period=period,
            gross_sales=round(data["gross"], 2),
            net_earnings=round(data["net"], 2),
            order_count=len(data["orders"]),
        )
        for period, data in sorted(weekly_map.items(), reverse=True)[:8]
    ]

    monthly_trends = [
        SalesTrendItem(
            period=period,
            gross_sales=round(data["gross"], 2),
            net_earnings=round(data["net"], 2),
            order_count=len(data["orders"]),
        )
        for period, data in sorted(monthly_map.items(), reverse=True)[:6]
    ]

    # Format best-selling products
    best_selling = [
        BestSellingProduct(
            product_id=pid,
            title=data["title"],
            quantity_sold=data["qty"],
            gross_revenue=round(data["gross"], 2),
            image_url=data["image_url"],
        )
        for pid, data in sorted(product_sales_map.items(), key=lambda x: x[1]["qty"], reverse=True)[:10]
    ]

    return ArtisanDashboardOut(
        artisan_id=profile.id,
        artisan_name=user.name,
        total_orders=len(valid_order_ids),
        products_sold=total_products_sold,
        gross_sales=gross_sales,
        platform_fees=platform_fees,
        refunds_cancellations=refunds_cancellations,
        net_earnings=net_earnings,
        settled_payout=settled_payout,
        pending_payout=pending_payout,
        daily_trends=daily_trends,
        weekly_trends=weekly_trends,
        monthly_trends=monthly_trends,
        best_selling_products=best_selling,
        recent_orders=recent_orders_list,
    )
