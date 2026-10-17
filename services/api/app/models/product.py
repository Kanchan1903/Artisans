"""Product, Category, ProductImage, and ProductTranslation models."""
import enum
from datetime import datetime
from sqlalchemy import (
    String, Text, Integer, Float, Boolean, DateTime, Enum as SAEnum,
    ForeignKey, JSON, ARRAY, func
)
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base


class ProductStatus(str, enum.Enum):
    draft = "draft"
    published = "published"
    hidden = "hidden"
    rejected = "rejected"


class Category(Base):
    """Product categories (Pottery, Weaving, Jewellery, etc)."""
    __tablename__ = "categories"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String(100), unique=True, nullable=False)
    name_hi: Mapped[str | None] = mapped_column(String(100), nullable=True)
    slug: Mapped[str] = mapped_column(String(100), unique=True, index=True, nullable=False)
    icon_url: Mapped[str | None] = mapped_column(Text, nullable=True)

    products: Mapped[list["Product"]] = relationship(back_populates="category")


class Product(Base):
    """Artisan product listing."""
    __tablename__ = "products"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    artisan_id: Mapped[int] = mapped_column(Integer, ForeignKey("artisan_profiles.id"), nullable=False)
    category_id: Mapped[int | None] = mapped_column(Integer, ForeignKey("categories.id"), nullable=True)

    # English content (canonical)
    title_en: Mapped[str] = mapped_column(String(255), nullable=False)
    description_en: Mapped[str | None] = mapped_column(Text, nullable=True)

    # Hindi content
    title_hi: Mapped[str | None] = mapped_column(String(255), nullable=True)
    description_hi: Mapped[str | None] = mapped_column(Text, nullable=True)

    # Craft metadata
    material: Mapped[str | None] = mapped_column(String(255), nullable=True)
    technique: Mapped[str | None] = mapped_column(String(255), nullable=True)
    care_instructions: Mapped[str | None] = mapped_column(Text, nullable=True)
    seo_keywords: Mapped[list | None] = mapped_column(JSON, nullable=True)  # stored as JSON array

    # Commerce
    price: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)
    stock: Mapped[int] = mapped_column(Integer, default=1)
    status: Mapped[ProductStatus] = mapped_column(SAEnum(ProductStatus, native_enum=False), default=ProductStatus.draft)

    # AI metadata
    voice_transcript: Mapped[str | None] = mapped_column(Text, nullable=True)
    ai_generated: Mapped[bool] = mapped_column(Boolean, default=False)

    published_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    idempotency_key: Mapped[str | None] = mapped_column(String(100), nullable=True, unique=True, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    # Relationships
    artisan: Mapped["ArtisanProfile"] = relationship(back_populates="products")  # type: ignore # noqa: F821
    category: Mapped["Category | None"] = relationship(back_populates="products")
    images: Mapped[list["ProductImage"]] = relationship(back_populates="product", cascade="all, delete-orphan")
    translations: Mapped[list["ProductTranslation"]] = relationship(back_populates="product", cascade="all, delete-orphan")
    order_items: Mapped[list["OrderItem"]] = relationship(back_populates="product")  # type: ignore # noqa: F821
    reviews: Mapped[list["Review"]] = relationship(back_populates="product")  # type: ignore # noqa: F821
    inquiries: Mapped[list["Inquiry"]] = relationship(back_populates="product")  # type: ignore # noqa: F821


class ProductImage(Base):
    """Product image records (hosted on MinIO)."""
    __tablename__ = "product_images"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    product_id: Mapped[int] = mapped_column(Integer, ForeignKey("products.id"), nullable=False)
    url: Mapped[str] = mapped_column(Text, nullable=False)
    is_primary: Mapped[bool] = mapped_column(Boolean, default=False)
    order_index: Mapped[int] = mapped_column(Integer, default=0)

    product: Mapped["Product"] = relationship(back_populates="images")


class ProductTranslation(Base):
    """AI-generated translations of a product into each supported language."""
    __tablename__ = "product_translations"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    product_id: Mapped[int] = mapped_column(Integer, ForeignKey("products.id"), nullable=False)
    language: Mapped[str] = mapped_column(String(10), nullable=False)  # en, hi, mr, ...
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)

    product: Mapped["Product"] = relationship(back_populates="translations")
