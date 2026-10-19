"""Wishlist schemas."""
from datetime import datetime
from pydantic import BaseModel
from app.schemas.product import ProductOut


class WishlistItemOut(BaseModel):
    id: int
    user_id: int
    product_id: int
    created_at: datetime
    product: ProductOut

    model_config = {"from_attributes": True}


class WishlistToggleOut(BaseModel):
    wishlisted: bool
    message: str
