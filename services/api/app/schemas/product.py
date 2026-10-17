"""Pydantic schemas for products, categories, images, and translations."""
from datetime import datetime
from pydantic import BaseModel, Field, ConfigDict
from app.models.product import ProductStatus
from app.schemas.artisan import ArtisanPublicOut


class CategoryOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    name_hi: str | None = None
    slug: str
    icon_url: str | None = None


class ProductImageBase(BaseModel):
    url: str
    is_primary: bool = False
    order_index: int = 0


class ProductImageCreate(ProductImageBase):
    pass


class ProductImageOut(ProductImageBase):
    model_config = ConfigDict(from_attributes=True)

    id: int


class ProductTranslationBase(BaseModel):
    language: str
    title: str
    description: str | None = None


class ProductTranslationCreate(ProductTranslationBase):
    pass


class ProductTranslationOut(ProductTranslationBase):
    model_config = ConfigDict(from_attributes=True)

    id: int


class ProductCreate(BaseModel):
    category_id: int | None = None
    title_en: str = Field(..., min_length=2, max_length=255)
    description_en: str | None = None
    title_hi: str | None = None
    description_hi: str | None = None
    material: str | None = None
    technique: str | None = None
    care_instructions: str | None = None
    seo_keywords: list[str] | None = None
    price: float = Field(..., ge=0.0)
    stock: int = Field(default=1, ge=0)
    status: ProductStatus = ProductStatus.published
    voice_transcript: str | None = None
    ai_generated: bool = False
    images: list[ProductImageCreate] = []
    translations: list[ProductTranslationCreate] = []
    idempotency_key: str | None = None
    draft_product_id: int | None = None


class ProductUpdate(BaseModel):
    category_id: int | None = None
    title_en: str | None = None
    description_en: str | None = None
    title_hi: str | None = None
    description_hi: str | None = None
    material: str | None = None
    technique: str | None = None
    care_instructions: str | None = None
    seo_keywords: list[str] | None = None
    price: float | None = None
    stock: int | None = None
    status: ProductStatus | None = None


class ProductStockUpdate(BaseModel):
    stock: int = Field(..., ge=0)


class ProductOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    artisan_id: int
    category_id: int | None = None
    title_en: str
    description_en: str | None = None
    title_hi: str | None = None
    description_hi: str | None = None
    material: str | None = None
    technique: str | None = None
    care_instructions: str | None = None
    seo_keywords: list[str] | None = None
    price: float
    stock: int
    status: ProductStatus
    voice_transcript: str | None = None
    ai_generated: bool
    published_at: datetime | None = None
    idempotency_key: str | None = None
    created_at: datetime
    updated_at: datetime
    images: list[ProductImageOut] = []
    translations: list[ProductTranslationOut] = []
    category: CategoryOut | None = None
    artisan: ArtisanPublicOut | None = None


class ProductListResponse(BaseModel):
    items: list[ProductOut]
    total: int
    page: int
    size: int


class ReviewCreate(BaseModel):
    rating: float = Field(..., ge=1.0, le=5.0)
    comment: str | None = None


class ReviewOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    product_id: int
    buyer_id: int
    rating: float
    comment: str | None = None
    created_at: datetime
    buyer_name: str | None = None
