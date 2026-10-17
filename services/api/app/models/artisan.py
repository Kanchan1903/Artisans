"""Artisan profile model — extended data for artisan users."""
from datetime import datetime
from sqlalchemy import String, Boolean, DateTime, Text, Integer, ForeignKey, JSON, func
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base


class ArtisanProfile(Base):
    """Extended profile for artisan users."""
    __tablename__ = "artisan_profiles"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), unique=True, nullable=False)

    # Craft & Location
    craft_type: Mapped[str | None] = mapped_column(String(100), nullable=True)
    village: Mapped[str | None] = mapped_column(String(255), nullable=True)
    district: Mapped[str | None] = mapped_column(String(255), nullable=True)
    state: Mapped[str | None] = mapped_column(String(100), nullable=True)

    # Story
    bio: Mapped[str | None] = mapped_column(Text, nullable=True)
    bio_hi: Mapped[str | None] = mapped_column(Text, nullable=True)   # Hindi bio
    bio_mr: Mapped[str | None] = mapped_column(Text, nullable=True)   # Marathi bio
    years_experience: Mapped[int | None] = mapped_column(Integer, nullable=True)

    # Media
    profile_photo_url: Mapped[str | None] = mapped_column(Text, nullable=True)

    # Financial
    upi_id: Mapped[str | None] = mapped_column(String(100), nullable=True)
    bank_details: Mapped[dict | None] = mapped_column(JSON, nullable=True)  # {bank, account, ifsc}

    # Admin
    is_approved: Mapped[bool] = mapped_column(Boolean, default=False)
    approved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    rejection_reason: Mapped[str | None] = mapped_column(Text, nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    # Relationships
    user: Mapped["User"] = relationship(back_populates="artisan_profile")  # type: ignore # noqa: F821
    products: Mapped[list["Product"]] = relationship(back_populates="artisan")  # type: ignore # noqa: F821
    earnings: Mapped[list["Earning"]] = relationship(back_populates="artisan")  # type: ignore # noqa: F821
    order_items: Mapped[list["OrderItem"]] = relationship(back_populates="artisan")  # type: ignore # noqa: F821
