"""Add idempotency keys for artisan original-image uploads.

Revision ID: 004_product_image_upload_keys
Revises: 003_image_job_output_json
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "004_product_image_upload_keys"
down_revision: Union[str, None] = "003_image_job_output_json"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("product_images", sa.Column("upload_key", sa.String(length=64), nullable=True))
    op.create_index("ix_product_images_upload_key", "product_images", ["upload_key"], unique=True)


def downgrade() -> None:
    op.drop_index("ix_product_images_upload_key", table_name="product_images")
    op.drop_column("product_images", "upload_key")
