"""Pydantic schemas for B2B wholesale inquiries."""
from datetime import datetime
from pydantic import BaseModel, Field, ConfigDict


class InquiryCreate(BaseModel):
    product_id: int
    buyer_name: str | None = None
    buyer_email: str | None = None
    message: str = Field(..., min_length=5, description="Buyer inquiry message in English or any language")
    quantity_needed: int | None = Field(None, ge=1)
    is_b2b: bool = True


class InquiryOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    product_id: int
    artisan_id: int
    buyer_id: int | None = None
    buyer_name: str | None = None
    buyer_email: str | None = None
    message_en: str
    message_translated: str | None = None
    is_b2b: bool
    quantity_needed: int | None = None
    is_read: bool
    created_at: datetime
    product_title: str | None = None
