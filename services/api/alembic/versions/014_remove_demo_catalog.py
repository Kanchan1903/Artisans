"""Remove all demo catalog products from database.

Revision ID: 014_remove_demo_catalog
Revises: 013_inquiry_workflow_fields
Create Date: 2026-11-20
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "014_remove_demo_catalog"
down_revision: Union[str, None] = "013_inquiry_workflow_fields"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

DEMO_KEYS = [
    "demo-catalog-folk-art-01",
    "demo-catalog-woodcraft-01",
    "demo-catalog-pottery-01",
    "demo-catalog-handloom-01",
    "demo-catalog-jewelry-01",
]


def upgrade() -> None:
    bind = op.get_bind()
    metadata = sa.MetaData()
    users = sa.Table("users", metadata, autoload_with=bind)
    artisans = sa.Table("artisan_profiles", metadata, autoload_with=bind)
    products = sa.Table("products", metadata, autoload_with=bind)
    product_images = sa.Table("product_images", metadata, autoload_with=bind)

    # 1. Find product IDs that match demo keys or titles containing 'DEMO'
    product_ids_by_key = bind.execute(
        sa.select(products.c.id).where(products.c.idempotency_key.in_(DEMO_KEYS))
    ).scalars().all()

    product_ids_by_title = bind.execute(
        sa.select(products.c.id).where(products.c.title_en.like("%DEMO%"))
    ).scalars().all()

    all_demo_product_ids = list(set(product_ids_by_key + product_ids_by_title))

    if all_demo_product_ids:
        bind.execute(
            sa.delete(product_images).where(
                product_images.c.product_id.in_(all_demo_product_ids)
            )
        )
        bind.execute(
            sa.delete(products).where(products.c.id.in_(all_demo_product_ids))
        )

    # 2. Clean up demo artisan profile and demo user
    demo_email = "demo-catalog@kalasathi.invalid"
    demo_user_id = bind.execute(
        sa.select(users.c.id).where(users.c.email == demo_email)
    ).scalar_one_or_none()

    if demo_user_id is not None:
        bind.execute(
            sa.delete(artisans).where(artisans.c.user_id == demo_user_id)
        )
        bind.execute(
            sa.delete(users).where(users.c.id == demo_user_id)
        )


def downgrade() -> None:
    pass
