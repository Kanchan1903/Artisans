"""B2B inquiry model."""
from datetime import datetime
from sqlalchemy import Integer, Text, Boolean, DateTime, ForeignKey, func
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base


class Inquiry(Base):
    __tablename__ = "inquiries"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    product_id: Mapped[int] = mapped_column(Integer, ForeignKey("products.id"), nullable=False)
    artisan_id: Mapped[int] = mapped_column(Integer, ForeignKey("artisan_profiles.id"), nullable=False)
    buyer_id: Mapped[int | None] = mapped_column(Integer, ForeignKey("users.id"), nullable=True)
    buyer_name: Mapped[str | None] = mapped_column(Text, nullable=True)  # for anonymous inquiries
    buyer_email: Mapped[str | None] = mapped_column(Text, nullable=True)
    message_en: Mapped[str] = mapped_column(Text, nullable=False)  # English version
    message_translated: Mapped[str | None] = mapped_column(Text, nullable=True)  # In artisan's language
    is_b2b: Mapped[bool] = mapped_column(Boolean, default=True)
    quantity_needed: Mapped[int | None] = mapped_column(Integer, nullable=True)
    is_read: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    product: Mapped["Product"] = relationship(back_populates="inquiries")  # type: ignore # noqa: F821
