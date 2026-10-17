"""Pydantic schemas for notifications."""
from datetime import datetime
from typing import Any
from pydantic import BaseModel, ConfigDict


class NotificationOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int
    type: str
    title: str
    body: str | None = None
    data: dict[str, Any] | None = None
    is_read: bool
    created_at: datetime
