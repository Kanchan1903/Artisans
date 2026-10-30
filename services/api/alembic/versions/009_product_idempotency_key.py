"""Add the product idempotency key used by current product queries.

Revision ID: 009_product_idempotency_key
Revises: 008_product_pricing_revisions
Create Date: 2026-10-30
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "009_product_idempotency_key"
down_revision: Union[str, None] = "008_product_pricing_revisions"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)

    columns = {column["name"] for column in inspector.get_columns("products")}
    if "idempotency_key" not in columns:
        op.add_column("products", sa.Column("idempotency_key", sa.String(length=100), nullable=True))

    indexes = {index["name"] for index in inspector.get_indexes("products")}
    if "ix_products_idempotency_key" not in indexes:
        op.create_index(
            "ix_products_idempotency_key",
            "products",
            ["idempotency_key"],
            unique=True,
        )


def downgrade() -> None:
    op.drop_index("ix_products_idempotency_key", table_name="products")
    op.drop_column("products", "idempotency_key")
