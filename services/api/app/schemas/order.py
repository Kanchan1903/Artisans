"""Pydantic schemas for orders and order items."""
from datetime import datetime
from typing import Any
from pydantic import BaseModel, Field, ConfigDict
from app.models.order import OrderStatus, PaymentMethod


class ShippingAddress(BaseModel):
    name: str = Field(..., min_length=2)
    phone: str = Field(..., min_length=10)
    line1: str = Field(...)
    line2: str | None = None
    city: str = Field(...)
    state: str = Field(...)
    pincode: str = Field(..., min_length=6, max_length=6)


class OrderItemCreate(BaseModel):
    product_id: int
    quantity: int = Field(default=1, ge=1)


class OrderCreate(BaseModel):
    items: list[OrderItemCreate] = Field(..., min_length=1)
    shipping_address: ShippingAddress
    payment_method: PaymentMethod = PaymentMethod.cod
    payment_id: str | None = None
    idempotency_key: str | None = None
    notes: str | None = None


class OrderItemOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    product_id: int
    artisan_id: int
    quantity: int
    unit_price: float
    product_title: str | None = None
    product_image_url: str | None = None


class OrderOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    buyer_id: int
    status: OrderStatus
    total: float
    shipping_address: dict[str, Any]
    payment_method: PaymentMethod
    payment_id: str | None = None
    payment_status: str = "unpaid"
    notes: str | None = None
    created_at: datetime
    updated_at: datetime
    items: list[OrderItemOut] = []


class OrderStatusUpdate(BaseModel):
    status: OrderStatus
