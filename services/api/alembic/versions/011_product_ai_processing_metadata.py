"""Persist product specifications and AI processing lifecycle."""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# Alembic's default PostgreSQL alembic_version.version_num column is VARCHAR(32).
# Keep this revision identifier within that limit.
revision: str = "011_product_ai_metadata"
down_revision: Union[str, None] = "010_demo_catalog"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("image_processing_jobs", sa.Column("input_json", sa.JSON(), nullable=True))
    op.add_column("products", sa.Column("dimensions", sa.String(length=100), nullable=True))
    op.add_column("products", sa.Column("weight_grams", sa.Float(), nullable=True))
    op.add_column("products", sa.Column("additional_details", sa.JSON(), nullable=True))
    op.add_column(
        "products",
        sa.Column("processing_status", sa.String(length=20), nullable=False, server_default="draft"),
    )
    op.add_column("products", sa.Column("ai_processing_result", sa.JSON(), nullable=True))


def downgrade() -> None:
    op.drop_column("image_processing_jobs", "input_json")
    op.drop_column("products", "ai_processing_result")
    op.drop_column("products", "processing_status")
    op.drop_column("products", "additional_details")
    op.drop_column("products", "weight_grams")
    op.drop_column("products", "dimensions")
