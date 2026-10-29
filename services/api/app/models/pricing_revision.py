"""Immutable, traceable snapshots of artisan pricing recommendations."""
from datetime import datetime

from sqlalchemy import (
    Boolean,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    JSON,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class PricingRevision(Base):
    __tablename__ = "product_pricing_revisions"
    __table_args__ = (
        UniqueConstraint("product_id", "version", name="uq_pricing_revision_product_version"),
        UniqueConstraint("product_id", "idempotency_key", name="uq_pricing_revision_idempotency"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    product_id: Mapped[int] = mapped_column(
        ForeignKey("products.id", ondelete="CASCADE"), nullable=False, index=True
    )
    artisan_id: Mapped[int] = mapped_column(
        ForeignKey("artisan_profiles.id", ondelete="CASCADE"), nullable=False, index=True
    )
    version: Mapped[int] = mapped_column(Integer, nullable=False)
    pricing_version: Mapped[str] = mapped_column(String(64), nullable=False)
    currency: Mapped[str] = mapped_column(String(3), nullable=False)
    suggested_price: Mapped[float | None] = mapped_column(Float, nullable=True)
    price_range_min: Mapped[float | None] = mapped_column(Float, nullable=True)
    price_range_max: Mapped[float | None] = mapped_column(Float, nullable=True)
    comparable_products: Mapped[list | None] = mapped_column(JSON, nullable=True)
    comparison_summary: Mapped[str] = mapped_column(Text, nullable=False)
    pricing_factors: Mapped[list | None] = mapped_column(JSON, nullable=True)
    confidence: Mapped[str] = mapped_column(String(16), nullable=False)
    requires_review: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    error: Mapped[str | None] = mapped_column(Text, nullable=True)

    challenge_reason: Mapped[str | None] = mapped_column(String(64), nullable=True)
    challenge_context: Mapped[str | None] = mapped_column(Text, nullable=True)
    previous_revision_id: Mapped[int | None] = mapped_column(
        ForeignKey("product_pricing_revisions.id", ondelete="SET NULL"), nullable=True
    )
    idempotency_key: Mapped[str | None] = mapped_column(String(80), nullable=True)

    selected_price: Mapped[float | None] = mapped_column(Float, nullable=True)
    selection_source: Mapped[str | None] = mapped_column(String(24), nullable=True)
    selected_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
