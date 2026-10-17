"""Pydantic schemas for authentication and user management."""
from datetime import datetime
from pydantic import BaseModel, Field, ConfigDict
from app.models.user import UserRole, Language


class OTPRequest(BaseModel):
    phone: str = Field(..., description="Phone number with country code, e.g. +919876543210")
    role: UserRole = Field(default=UserRole.artisan, description="Target role for user registration")


class OTPVerify(BaseModel):
    phone: str = Field(...)
    code: str = Field(..., min_length=4, max_length=6)
    name: str | None = None
    role: UserRole = Field(default=UserRole.buyer, description="Role to assign to new users")
    language: Language = Language.en


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: int
    role: UserRole
    name: str | None
    language: Language
    is_artisan: bool
    artisan_id: int | None = None


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    phone: str
    email: str | None = None
    name: str | None = None
    role: UserRole
    language: Language
    is_verified: bool
    fcm_token: str | None = None
    created_at: datetime


class UserUpdate(BaseModel):
    name: str | None = None
    email: str | None = None
    language: Language | None = None
    fcm_token: str | None = None
