"""Persist comparable snapshots, challenges, and artisan price selections.

Revision ID: 008_product_pricing_revisions
Revises: 007_product_voice_language
Create Date: 2026-10-29
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "008_product_pricing_revisions"
down_revision: Union[str, None] = "007_product_voice_language"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "product_pricing_revisions",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("product_id", sa.Integer(), sa.ForeignKey("products.id", ondelete="CASCADE"), nullable=False),
        sa.Column("artisan_id", sa.Integer(), sa.ForeignKey("artisan_profiles.id", ondelete="CASCADE"), nullable=False),
        sa.Column("version", sa.Integer(), nullable=False),
        sa.Column("pricing_version", sa.String(length=64), nullable=False),
        sa.Column("currency", sa.String(length=3), nullable=False),
        sa.Column("suggested_price", sa.Float(), nullable=True),
        sa.Column("price_range_min", sa.Float(), nullable=True),
        sa.Column("price_range_max", sa.Float(), nullable=True),
        sa.Column("comparable_products", sa.JSON(), nullable=True),
        sa.Column("comparison_summary", sa.Text(), nullable=False),
        sa.Column("pricing_factors", sa.JSON(), nullable=True),
        sa.Column("confidence", sa.String(length=16), nullable=False),
        sa.Column("requires_review", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("error", sa.Text(), nullable=True),
        sa.Column("challenge_reason", sa.String(length=64), nullable=True),
        sa.Column("challenge_context", sa.Text(), nullable=True),
        sa.Column("previous_revision_id", sa.Integer(), sa.ForeignKey("product_pricing_revisions.id", ondelete="SET NULL"), nullable=True),
        sa.Column("idempotency_key", sa.String(length=80), nullable=True),
        sa.Column("selected_price", sa.Float(), nullable=True),
        sa.Column("selection_source", sa.String(length=24), nullable=True),
        sa.Column("selected_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("product_id", "version", name="uq_pricing_revision_product_version"),
        sa.UniqueConstraint("product_id", "idempotency_key", name="uq_pricing_revision_idempotency"),
    )
    op.create_index("ix_product_pricing_revisions_product_id", "product_pricing_revisions", ["product_id"])
    op.create_index("ix_product_pricing_revisions_artisan_id", "product_pricing_revisions", ["artisan_id"])


def downgrade() -> None:
    op.drop_index("ix_product_pricing_revisions_artisan_id", table_name="product_pricing_revisions")
    op.drop_index("ix_product_pricing_revisions_product_id", table_name="product_pricing_revisions")
    op.drop_table("product_pricing_revisions")
