"""Add inquiry workflow, scheduling, and order confirmation columns.

Revision ID: 013_inquiry_workflow_fields
Revises: 012_inquiry_buyer_phone
Create Date: 2026-11-14
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "013_inquiry_workflow_fields"
down_revision: Union[str, None] = "012_inquiry_buyer_phone"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("inquiries", sa.Column("status", sa.String(length=32), nullable=False, server_default="new"))
    op.add_column("inquiries", sa.Column("scheduled_contact_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("inquiries", sa.Column("contact_notes", sa.Text(), nullable=True))
    op.add_column("inquiries", sa.Column("artisan_response", sa.Text(), nullable=True))
    op.add_column("inquiries", sa.Column("agreed_price", sa.Float(), nullable=True))
    op.add_column("inquiries", sa.Column("agreed_quantity", sa.Integer(), nullable=True))
    op.add_column("inquiries", sa.Column("delivery_details", sa.Text(), nullable=True))
    op.add_column("inquiries", sa.Column("confirmed_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("inquiries", sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True))


def downgrade() -> None:
    op.drop_column("inquiries", "completed_at")
    op.drop_column("inquiries", "confirmed_at")
    op.drop_column("inquiries", "delivery_details")
    op.drop_column("inquiries", "agreed_quantity")
    op.drop_column("inquiries", "agreed_price")
    op.drop_column("inquiries", "artisan_response")
    op.drop_column("inquiries", "contact_notes")
    op.drop_column("inquiries", "scheduled_contact_at")
    op.drop_column("inquiries", "status")
