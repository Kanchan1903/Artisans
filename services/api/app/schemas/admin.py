"""Pydantic schemas for admin panel."""
from pydantic import BaseModel
from app.models.product import ProductStatus


class ArtisanApprovalRequest(BaseModel):
    is_approved: bool
    rejection_reason: str | None = None


class ProductModerationRequest(BaseModel):
    status: ProductStatus


class AdminStatsOut(BaseModel):
    total_artisans: int
    approved_artisans: int
    pending_artisans: int
    total_products: int
    published_products: int
    total_orders: int
    total_revenue: float
    total_inquiries: int
