"""Request and response schemas for artisan pricing review."""
from typing import Literal

from pydantic import BaseModel, Field


class PricingRecommendationIn(BaseModel):
    idempotency_key: str | None = Field(default=None, min_length=8, max_length=80)
    material_cost: float | None = Field(default=None, ge=0, le=1000000000)
    labor_hours: float | None = Field(default=None, gt=0, le=1000000)
    hourly_rate: float | None = Field(default=None, ge=0, le=1000000000)
    packaging_cost: float | None = Field(default=None, ge=0, le=1000000000)
    shipping_cost: float | None = Field(default=None, ge=0, le=1000000000)


class PricingChallengeIn(PricingRecommendationIn):
    previous_revision_id: int = Field(..., ge=1)
    reason: Literal[
        "material_cost",
        "labor",
        "size_or_detail",
        "market_difference",
        "other",
    ]
    context: str | None = Field(default=None, max_length=2000)


class PricingSelectionIn(BaseModel):
    revision_id: int = Field(..., ge=1)
    price: float = Field(..., gt=0, le=1000000000)
    selection_source: Literal["suggested", "custom", "revised_suggestion"]


class ComparableProductOut(BaseModel):
    product_id: int
    title: str
    price: float
    currency: str
    category: str | None = None
    material: str | None = None
    technique: str | None = None
    similarity_score: float
    product_url: str


class PricingRecommendationOut(BaseModel):
    revision_id: int
    product_id: int
    version: int
    suggested_price: float | None
    currency: str
    price_range_min: float | None
    price_range_max: float | None
    comparable_products: list[ComparableProductOut]
    comparison_summary: str
    pricing_factors: list[str]
    confidence: Literal["none", "low", "medium", "high"]
    requires_review: bool
    pricing_version: str
    error: str | None = None
    challenge_reason: str | None = None
    challenge_context: str | None = None
    previous_revision_id: int | None = None
    selected_price: float | None = None
    selection_source: str | None = None
    created_at: str
