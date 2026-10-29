"""Add persistent image-processing jobs for the artisan CrewAI workflow.

Revision ID: 002_image_processing_jobs
Revises: 001_initial_schema
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "002_image_processing_jobs"
down_revision: Union[str, None] = "001_initial_schema"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "image_processing_jobs",
        sa.Column("id", sa.String(length=64), nullable=False),
        sa.Column("artisan_id", sa.Integer(), nullable=False),
        sa.Column("product_id", sa.Integer(), nullable=True),
        sa.Column("product_name", sa.String(length=255), nullable=True),
        sa.Column("product_category", sa.String(length=100), nullable=True),
        sa.Column("status", sa.String(length=40), nullable=False),
        sa.Column("segmentation_status", sa.String(length=40), nullable=True),
        sa.Column("original_photo_url", sa.Text(), nullable=False),
        sa.Column("original_storage_key", sa.String(length=255), nullable=True),
        sa.Column("cutout_url", sa.Text(), nullable=True),
        sa.Column("cutout_storage_key", sa.String(length=255), nullable=True),
        sa.Column("variants", sa.JSON(), nullable=True),
        sa.Column("quality_warnings", sa.JSON(), nullable=True),
        sa.Column("errors", sa.JSON(), nullable=True),
        sa.Column("requires_review", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("crewai_execution_id", sa.String(length=100), nullable=True),
        sa.Column("selected_variant_ids", sa.JSON(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(["artisan_id"], ["artisan_profiles.id"]),
        sa.ForeignKeyConstraint(["product_id"], ["products.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_image_processing_jobs_artisan_id", "image_processing_jobs", ["artisan_id"])
    op.create_index("ix_image_processing_jobs_product_id", "image_processing_jobs", ["product_id"])
    op.create_index("ix_image_processing_jobs_status", "image_processing_jobs", ["status"])
    op.create_index("ix_image_processing_jobs_crewai_execution_id", "image_processing_jobs", ["crewai_execution_id"])


def downgrade() -> None:
    op.drop_index("ix_image_processing_jobs_crewai_execution_id", table_name="image_processing_jobs")
    op.drop_index("ix_image_processing_jobs_status", table_name="image_processing_jobs")
    op.drop_index("ix_image_processing_jobs_product_id", table_name="image_processing_jobs")
    op.drop_index("ix_image_processing_jobs_artisan_id", table_name="image_processing_jobs")
    op.drop_table("image_processing_jobs")
