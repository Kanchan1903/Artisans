"""Pydantic schemas for artisan profiles."""
from datetime import datetime
from typing import Any
from pydantic import BaseModel, Field, ConfigDict
from app.schemas.auth import UserOut


class BankDetails(BaseModel):
    account_holder_name: str | None = None
    account_number: str | None = None
    ifsc_code: str | None = None
    bank_name: str | None = None


class ArtisanProfileBase(BaseModel):
    craft_type: str | None = Field(None, json_schema_extra={"example": "Terracotta Pottery"})
    village: str | None = Field(None, json_schema_extra={"example": "Bishnupur"})
    district: str | None = Field(None, json_schema_extra={"example": "Bankura"})
    state: str | None = Field(None, json_schema_extra={"example": "West Bengal"})
    bio: str | None = None
    bio_hi: str | None = None
    bio_mr: str | None = None
    years_experience: int | None = None
    profile_photo_url: str | None = None
    upi_id: str | None = None
    bank_details: dict[str, Any] | None = None


class ArtisanProfileCreate(ArtisanProfileBase):
    pass


class ArtisanProfileUpdate(ArtisanProfileBase):
    pass


class ArtisanProfileOut(ArtisanProfileBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int
    is_approved: bool
    approved_at: datetime | None = None
    rejection_reason: str | None = None
    created_at: datetime
    updated_at: datetime
    user: UserOut | None = None


class ArtisanPublicOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int
    name: str | None = None
    craft_type: str | None = None
    village: str | None = None
    district: str | None = None
    state: str | None = None
    bio: str | None = None
    bio_hi: str | None = None
    bio_mr: str | None = None
    profile_photo_url: str | None = None
    years_experience: int | None = None
    is_approved: bool = True
    product_count: int = 0
