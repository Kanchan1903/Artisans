"""Product review model."""
from datetime import datetime
from sqlalchemy import Integer, Float, Text, DateTime, ForeignKey, func
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base


class Review(Base):
    __tablename__ = "reviews"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    product_id: Mapped[int] = mapped_column(Integer, ForeignKey("products.id"), nullable=False)
    buyer_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), nullable=False)
    rating: Mapped[float] = mapped_column(Float, nullable=False)  # 1.0 – 5.0
    comment: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    product: Mapped["Product"] = relationship(back_populates="reviews")  # type: ignore # noqa: F821
    buyer: Mapped["User"] = relationship(back_populates="reviews")  # type: ignore # noqa: F821

    @property
    def buyer_name(self) -> str | None:
        try:
            return self.buyer.name if self.buyer else None
        except Exception:
            return None
