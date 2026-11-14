"""Add buyer_phone to inquiries.

Revision ID: 012_inquiry_buyer_phone
Revises: 011_product_ai_metadata
Create Date: 2026-11-14
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "012_inquiry_buyer_phone"
down_revision: Union[str, None] = "011_product_ai_metadata"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("inquiries", sa.Column("buyer_phone", sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column("inquiries", "buyer_phone")
