"""Add password hash column used by the current user model.

Revision ID: 005_user_password_hash
Revises: 004_product_image_upload_keys
Create Date: 2026-10-29
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "005_user_password_hash"
down_revision: Union[str, None] = "004_product_image_upload_keys"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("users", sa.Column("password_hash", sa.String(length=255), nullable=True))


def downgrade() -> None:
    op.drop_column("users", "password_hash")
