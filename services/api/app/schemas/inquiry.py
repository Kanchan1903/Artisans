"""Pydantic schemas for B2B wholesale inquiries, scheduling, and order confirmation."""
from datetime import datetime
from pydantic import BaseModel, Field, ConfigDict


class InquiryCreate(BaseModel):
    product_id: int
    buyer_name: str | None = None
    buyer_email: str | None = None
    buyer_phone: str | None = None
    message: str = Field(..., min_length=5, description="Buyer inquiry message in English or any language")
    quantity_needed: int | None = Field(None, ge=1)
    is_b2b: bool = True


class InquiryStatusUpdate(BaseModel):
    status: str = Field(..., description="new, accepted, contact_scheduled, contacted, negotiation, order_confirmed, completed, rejected, contact_later")
    scheduled_contact_at: datetime | None = None
    contact_notes: str | None = None
    artisan_response: str | None = None


class InquiryOrderConfirm(BaseModel):
    agreed_price: float = Field(..., gt=0, description="Final agreed unit or total price")
    agreed_quantity: int = Field(..., ge=1, description="Final agreed quantity")
    delivery_details: str = Field(..., min_length=3, description="Delivery address or timeline agreed upon")
    contact_notes: str | None = None


class InquiryOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    product_id: int
    artisan_id: int
    buyer_id: int | None = None
    buyer_name: str | None = None
    buyer_email: str | None = None
    buyer_phone: str | None = None
    message_en: str
    message_translated: str | None = None
    is_b2b: bool
    quantity_needed: int | None = None
    is_read: bool
    created_at: datetime
    product_title: str | None = None
    product_image_url: str | None = None

    status: str = "new"
    scheduled_contact_at: datetime | None = None
    contact_notes: str | None = None
    artisan_response: str | None = None

    agreed_price: float | None = None
    agreed_quantity: int | None = None
    delivery_details: str | None = None
    confirmed_at: datetime | None = None
    completed_at: datetime | None = None
