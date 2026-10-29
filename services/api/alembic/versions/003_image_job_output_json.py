"""Persist normalized CrewAI image results as queryable JSON.

Revision ID: 003_image_job_output_json
Revises: 002_image_processing_jobs
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "003_image_job_output_json"
down_revision: Union[str, None] = "002_image_processing_jobs"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("image_processing_jobs", sa.Column("output_json", sa.JSON(), nullable=True))


def downgrade() -> None:
    op.drop_column("image_processing_jobs", "output_json")
