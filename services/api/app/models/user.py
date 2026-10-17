"""User and OTP models."""
import enum
from datetime import datetime
from sqlalchemy import String, Boolean, DateTime, Enum as SAEnum, Text, Integer, func
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base


class UserRole(str, enum.Enum):
    artisan = "artisan"
    buyer = "buyer"
    admin = "admin"


class Language(str, enum.Enum):
    en = "en"      # English
    hi = "hi"      # Hindi
    mr = "mr"      # Marathi
    bn = "bn"      # Bengali
    ta = "ta"      # Tamil
    te = "te"      # Telugu
    kn = "kn"      # Kannada
    ml = "ml"      # Malayalam
    gu = "gu"      # Gujarati
    pa = "pa"      # Punjabi
    or_ = "or"     # Odia
    as_ = "as"     # Assamese


class User(Base):
    """Platform user — can be artisan, buyer, or admin."""
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    phone: Mapped[str] = mapped_column(String(20), unique=True, index=True, nullable=False)
    email: Mapped[str | None] = mapped_column(String(255), unique=True, index=True, nullable=True)
    name: Mapped[str | None] = mapped_column(String(255), nullable=True)
    role: Mapped[UserRole] = mapped_column(SAEnum(UserRole, native_enum=False), default=UserRole.buyer, nullable=False)
    language: Mapped[Language] = mapped_column(SAEnum(Language, native_enum=False), default=Language.en, nullable=False)
    is_verified: Mapped[bool] = mapped_column(Boolean, default=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    fcm_token: Mapped[str | None] = mapped_column(Text, nullable=True)  # Firebase push token
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    # Relationships
    artisan_profile: Mapped["ArtisanProfile | None"] = relationship(back_populates="user", uselist=False)  # type: ignore # noqa: F821
    orders: Mapped[list["Order"]] = relationship(back_populates="buyer", foreign_keys="Order.buyer_id")  # type: ignore # noqa: F821
    notifications: Mapped[list["Notification"]] = relationship(back_populates="user")  # type: ignore # noqa: F821
    reviews: Mapped[list["Review"]] = relationship(back_populates="buyer")  # type: ignore # noqa: F821


class OTPCode(Base):
    """One-time password records for phone verification."""
    __tablename__ = "otp_codes"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    phone: Mapped[str] = mapped_column(String(20), index=True, nullable=False)
    code: Mapped[str] = mapped_column(String(10), nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    is_used: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
