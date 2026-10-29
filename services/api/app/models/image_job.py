"""Image processing job records produced by the CrewAI workflow."""
import enum
from datetime import datetime
from sqlalchemy import String, Text, Integer, Boolean, DateTime, ForeignKey, JSON, func, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class ImageJobStatus(str, enum.Enum):
    queued = "queued"
    running = "running"
    completed = "completed"
    failed = "failed"
    retake_required = "retake_required"


class ImageProcessingJob(Base):
    """Persists CrewAI image-processing inputs, status, variants, and artisan selection."""

    __tablename__ = "image_processing_jobs"
    __table_args__ = (
        UniqueConstraint("artisan_id", "idempotency_key", name="uq_image_job_artisan_idempotency"),
    )

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    artisan_id: Mapped[int] = mapped_column(Integer, ForeignKey("artisan_profiles.id"), nullable=False, index=True)
    product_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("products.id", ondelete="SET NULL"), nullable=True, index=True
    )

    product_name: Mapped[str | None] = mapped_column(String(255), nullable=True)
    product_category: Mapped[str | None] = mapped_column(String(100), nullable=True)
    idempotency_key: Mapped[str | None] = mapped_column(String(100), nullable=True)

    status: Mapped[str] = mapped_column(String(40), default=ImageJobStatus.queued.value, index=True)
    segmentation_status: Mapped[str | None] = mapped_column(String(40), nullable=True)

    original_photo_url: Mapped[str] = mapped_column(Text, nullable=False)
    original_storage_key: Mapped[str | None] = mapped_column(String(255), nullable=True)
    cutout_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    cutout_storage_key: Mapped[str | None] = mapped_column(String(255), nullable=True)

    variants: Mapped[list | None] = mapped_column(JSON, nullable=True)
    output_json: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    quality_warnings: Mapped[list | None] = mapped_column(JSON, nullable=True)
    errors: Mapped[list | None] = mapped_column(JSON, nullable=True)
    requires_review: Mapped[bool] = mapped_column(Boolean, default=False)

    crewai_execution_id: Mapped[str | None] = mapped_column(String(100), nullable=True, index=True)
    selected_variant_ids: Mapped[list | None] = mapped_column(JSON, nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    artisan: Mapped["ArtisanProfile"] = relationship()  # type: ignore # noqa: F821
    product: Mapped["Product | None"] = relationship()  # type: ignore # noqa: F821
