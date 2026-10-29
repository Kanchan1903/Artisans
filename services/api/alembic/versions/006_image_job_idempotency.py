"""Add per-artisan idempotency keys for image-processing jobs.

Revision ID: 006_image_job_idempotency
Revises: 005_user_password_hash
Create Date: 2026-10-29
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "006_image_job_idempotency"
down_revision: Union[str, None] = "005_user_password_hash"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "image_processing_jobs",
        sa.Column("idempotency_key", sa.String(length=100), nullable=True),
    )
    op.create_unique_constraint(
        "uq_image_job_artisan_idempotency",
        "image_processing_jobs",
        ["artisan_id", "idempotency_key"],
    )


def downgrade() -> None:
    op.drop_constraint(
        "uq_image_job_artisan_idempotency", "image_processing_jobs", type_="unique"
    )
    op.drop_column("image_processing_jobs", "idempotency_key")
