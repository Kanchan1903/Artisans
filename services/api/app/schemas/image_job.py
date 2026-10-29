from __future__ import annotations

from datetime import datetime
from pydantic import BaseModel, Field, ConfigDict, model_validator


class ImageVariantOut(BaseModel):
    model_config = ConfigDict(from_attributes=True, extra="ignore")

    id: str
    variant_id: str | None = None
    background: dict = Field(default_factory=dict)
    image_url: str | None = None
    storage_key: str | None = None
    saved: bool = True
    status: str = "ready"

    @model_validator(mode="before")
    @classmethod
    def populate_variant_id(cls, data: dict):
        if isinstance(data, dict):
            if "variant_id" not in data and "id" in data:
                data["variant_id"] = data["id"]
            elif "id" not in data and "variant_id" in data:
                data["id"] = data["variant_id"]
        return data


class ImageJobOut(BaseModel):
    model_config = ConfigDict(from_attributes=True, extra="ignore")

    job_id: str
    artisan_id: str | int
    product_id: str | int | None = None
    product_name: str | None = None
    product_category: str | None = None
    status: str
    segmentation_status: str | None = None
    original_photo: dict = Field(default_factory=dict)
    cutout: dict = Field(default_factory=dict)
    original_photo_url: str | None = None
    original_storage_key: str | None = None
    cutout_url: str | None = None
    cutout_storage_key: str | None = None
    variants: list[ImageVariantOut] = []
    output_json: dict | None = None
    required_selection_count: int = 3
    selected_variant_ids: list[str] = []
    error: str | None = None
    warnings: list[str] = []
    quality_warnings: list[str] = []
    errors: list[str] = []
    requires_review: bool = False
    crewai_execution_id: str | None = None
    processing_mode: str = "real"
    created_at: datetime | None = None
    updated_at: datetime | None = None


class SelectVariantsIn(BaseModel):
    variant_ids: list[str] = Field(default_factory=list)
    selected_variant_ids: list[str] = Field(default_factory=list)

    @model_validator(mode="after")
    def unify_ids(self):
        ids = self.variant_ids or self.selected_variant_ids
        if len(ids) != 3:
            raise ValueError("Exactly three variants must be selected")
        if len(set(ids)) != 3:
            raise ValueError("All three variant selections must be unique (no duplicates)")
        self.variant_ids = ids
        self.selected_variant_ids = ids
        return self


class ReviewImageJobIn(BaseModel):
    approved: bool
