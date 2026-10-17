"""Artisan earnings model."""
import enum
from datetime import datetime
from sqlalchemy import Integer, Float, String, DateTime, ForeignKey, Enum as SAEnum, func
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base


class EarningStatus(str, enum.Enum):
    pending = "pending"
    settled = "settled"
    cancelled = "cancelled"


class Earning(Base):
    __tablename__ = "earnings"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    artisan_id: Mapped[int] = mapped_column(Integer, ForeignKey("artisan_profiles.id"), nullable=False)
    order_item_id: Mapped[int | None] = mapped_column(Integer, ForeignKey("order_items.id"), nullable=True)
    amount: Mapped[float] = mapped_column(Float, nullable=False)
    status: Mapped[EarningStatus] = mapped_column(SAEnum(EarningStatus, native_enum=False), default=EarningStatus.pending)
    settled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    artisan: Mapped["ArtisanProfile"] = relationship(back_populates="earnings")  # type: ignore # noqa: F821
    order_item: Mapped["OrderItem | None"] = relationship(back_populates="earning")  # type: ignore # noqa: F821
