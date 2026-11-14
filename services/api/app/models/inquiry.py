"""Inquiry status, scheduled contact, and order confirmation workflow models."""
from datetime import datetime
from enum import Enum
from sqlalchemy import Integer, Text, Boolean, DateTime, Float, ForeignKey, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base


class InquiryStatus(str, Enum):
    new = "new"
    accepted = "accepted"
    contact_scheduled = "contact_scheduled"
    contacted = "contacted"
    negotiation = "negotiation"
    order_confirmed = "order_confirmed"
    completed = "completed"
    rejected = "rejected"
    contact_later = "contact_later"


class Inquiry(Base):
    __tablename__ = "inquiries"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    product_id: Mapped[int] = mapped_column(Integer, ForeignKey("products.id"), nullable=False)
    artisan_id: Mapped[int] = mapped_column(Integer, ForeignKey("artisan_profiles.id"), nullable=False)
    buyer_id: Mapped[int | None] = mapped_column(Integer, ForeignKey("users.id"), nullable=True)
    buyer_name: Mapped[str | None] = mapped_column(Text, nullable=True)  # for anonymous inquiries
    buyer_email: Mapped[str | None] = mapped_column(Text, nullable=True)
    buyer_phone: Mapped[str | None] = mapped_column(Text, nullable=True)
    message_en: Mapped[str] = mapped_column(Text, nullable=False)  # English version
    message_translated: Mapped[str | None] = mapped_column(Text, nullable=True)  # In artisan's language
    is_b2b: Mapped[bool] = mapped_column(Boolean, default=True)
    quantity_needed: Mapped[int | None] = mapped_column(Integer, nullable=True)
    is_read: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    # Inquiry Workflow & Contact Control
    status: Mapped[str] = mapped_column(String(32), default="new", nullable=False)
    scheduled_contact_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    contact_notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    artisan_response: Mapped[str | None] = mapped_column(Text, nullable=True)

    # Order Confirmation Fields (when converted to confirmed order)
    agreed_price: Mapped[float | None] = mapped_column(Float, nullable=True)
    agreed_quantity: Mapped[int | None] = mapped_column(Integer, nullable=True)
    delivery_details: Mapped[str | None] = mapped_column(Text, nullable=True)
    confirmed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    product: Mapped["Product"] = relationship(back_populates="inquiries")  # type: ignore # noqa: F821
