"""Persist the language used for an artisan's original product transcript.

Revision ID: 007_product_voice_language
Revises: 006_image_job_idempotency
Create Date: 2026-10-29
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "007_product_voice_language"
down_revision: Union[str, None] = "006_image_job_idempotency"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("products", sa.Column("voice_language", sa.String(length=5), nullable=True))


def downgrade() -> None:
    op.drop_column("products", "voice_language")
