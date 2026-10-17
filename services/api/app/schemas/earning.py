"""Pydantic schemas for artisan earnings."""
from datetime import datetime
from pydantic import BaseModel, ConfigDict
from app.models.earning import EarningStatus


class EarningOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    artisan_id: int
    order_item_id: int | None = None
    amount: float
    status: EarningStatus
    settled_at: datetime | None = None
    created_at: datetime


class MonthlyEarning(BaseModel):
    month: str  # e.g. "2026-10"
    amount: float
    order_count: int


class EarningsSummaryOut(BaseModel):
    total_earnings: float
    settled_earnings: float
    pending_earnings: float
    total_orders_fulfilled: int
    monthly_breakdown: list[MonthlyEarning] = []


class SalesTrendItem(BaseModel):
    period: str  # e.g. "2026-10-17" or "2026-W42" or "2026-10"
    gross_sales: float
    net_earnings: float
    order_count: int


class BestSellingProduct(BaseModel):
    product_id: int
    title: str
    quantity_sold: int
    gross_revenue: float
    image_url: str | None = None


class DashboardOrderSummary(BaseModel):
    order_id: int
    created_at: datetime
    status: str
    payment_method: str
    shipping_city: str
    total_amount: float
    artisan_net_earnings: float
    quantity: int
    product_title: str


class ArtisanDashboardOut(BaseModel):
    artisan_id: int
    artisan_name: str
    total_orders: int
    products_sold: int
    gross_sales: float
    platform_fees: float
    refunds_cancellations: float
    net_earnings: float
    settled_payout: float
    pending_payout: float
    daily_trends: list[SalesTrendItem] = []
    weekly_trends: list[SalesTrendItem] = []
    monthly_trends: list[SalesTrendItem] = []
    best_selling_products: list[BestSellingProduct] = []
    recent_orders: list[DashboardOrderSummary] = []

