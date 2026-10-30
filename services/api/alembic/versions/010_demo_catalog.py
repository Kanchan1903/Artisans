"""Populate a clearly labeled, non-purchasable demo catalog.

Revision ID: 010_demo_catalog
Revises: 009_product_idempotency_key
Create Date: 2026-10-30
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "010_demo_catalog"
down_revision: Union[str, None] = "009_product_idempotency_key"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, None] = None


CATEGORIES = [
    ("Tribal & Folk Art", "जनजातीय और लोक कला", "folk-art", "palette"),
    ("Woodcraft & Toys", "काष्ठकला और खिलौने", "woodcraft", "tree"),
    ("Pottery & Terracotta", "मिट्टी के बर्तन और टेराकोटा", "pottery", "circle"),
    ("Handloom & Textiles", "हथकरघा और वस्त्र", "handloom", "scissors"),
    ("Jewelry & Metalcraft", "पारंपरिक आभूषण व धातुशिल्प", "jewelry", "sparkles"),
]

PRODUCTS = [
    {
        "key": "demo-catalog-folk-art-01",
        "category": "folk-art",
        "title": "DEMO — Warli Motif Wall Art",
        "description": "Demo catalog item for storefront preview. This is not an actual artisan product and is not available for purchase.",
        "material": "Demo sample canvas and rice-paste motif",
        "technique": "Sample Warli-inspired line art",
        "price": 799.0,
        "image": "folk-art.jpg",
        "keywords": ["demo", "folk art", "warli", "wall art"],
    },
    {
        "key": "demo-catalog-woodcraft-01",
        "category": "woodcraft",
        "title": "DEMO — Lacquered Wooden Spinning Top Set",
        "description": "Demo catalog item for storefront preview. This is not an actual artisan product and is not available for purchase.",
        "material": "Demo sample hardwood and water-based lacquer",
        "technique": "Sample wood turning and lacquering",
        "price": 649.0,
        "image": "woodcraft.jpg",
        "keywords": ["demo", "woodcraft", "toy", "spinning top"],
    },
    {
        "key": "demo-catalog-pottery-01",
        "category": "pottery",
        "title": "DEMO — Terracotta Planter",
        "description": "Demo catalog item for storefront preview. This is not an actual artisan product and is not available for purchase.",
        "material": "Demo sample terracotta clay",
        "technique": "Sample hand-thrown pottery",
        "price": 549.0,
        "image": "pottery.jpg",
        "keywords": ["demo", "pottery", "terracotta", "planter"],
    },
    {
        "key": "demo-catalog-handloom-01",
        "category": "handloom",
        "title": "DEMO — Handwoven Cotton Table Runner",
        "description": "Demo catalog item for storefront preview. This is not an actual artisan product and is not available for purchase.",
        "material": "Demo sample handwoven cotton",
        "technique": "Sample handloom weaving",
        "price": 1199.0,
        "image": "handloom.jpg",
        "keywords": ["demo", "handloom", "cotton", "table runner"],
    },
    {
        "key": "demo-catalog-jewelry-01",
        "category": "jewelry",
        "title": "DEMO — Folk-Art Beaded Pendant Necklace",
        "description": "Demo catalog item for storefront preview. This is not an actual artisan product and is not available for purchase.",
        "material": "Demo sample beads and pendant",
        "technique": "Sample hand-assembled jewelry",
        "price": 899.0,
        "image": "jewelry.jpg",
        "keywords": ["demo", "jewelry", "pendant", "necklace"],
    },
]


def upgrade() -> None:
    bind = op.get_bind()
    metadata = sa.MetaData()
    users = sa.Table("users", metadata, autoload_with=bind)
    artisans = sa.Table("artisan_profiles", metadata, autoload_with=bind)
    categories = sa.Table("categories", metadata, autoload_with=bind)
    products = sa.Table("products", metadata, autoload_with=bind)
    product_images = sa.Table("product_images", metadata, autoload_with=bind)

    category_ids: dict[str, int] = {}
    for name, name_hi, slug, icon_url in CATEGORIES:
        category_id = bind.execute(
            sa.select(categories.c.id).where(categories.c.slug == slug)
        ).scalar_one_or_none()
        if category_id is None:
            category_id = bind.execute(
                sa.insert(categories)
                .values(name=name, name_hi=name_hi, slug=slug, icon_url=icon_url)
                .returning(categories.c.id)
            ).scalar_one()
        category_ids[slug] = category_id

    demo_email = "demo-catalog@kalasathi.invalid"
    user_id = bind.execute(
        sa.select(users.c.id).where(users.c.email == demo_email)
    ).scalar_one_or_none()
    if user_id is None:
        user_id = bind.execute(
            sa.insert(users)
            .values(
                phone="+910000000005",
                email=demo_email,
                name="DEMO — KalaSathi Sample Studio",
                role="artisan",
                language="en",
                is_verified=True,
                is_active=True,
            )
            .returning(users.c.id)
        ).scalar_one()

    artisan_id = bind.execute(
        sa.select(artisans.c.id).where(artisans.c.user_id == user_id)
    ).scalar_one_or_none()
    if artisan_id is None:
        artisan_id = bind.execute(
            sa.insert(artisans)
            .values(
                user_id=user_id,
                craft_type="DEMO catalog only",
                bio="Demo storefront profile. The items shown here are sample placeholders, not real artisan goods.",
                is_approved=False,
            )
            .returning(artisans.c.id)
        ).scalar_one()

    for item in PRODUCTS:
        existing_id = bind.execute(
            sa.select(products.c.id).where(products.c.idempotency_key == item["key"])
        ).scalar_one_or_none()
        if existing_id is not None:
            continue

        product_id = bind.execute(
            sa.insert(products)
            .values(
                artisan_id=artisan_id,
                category_id=category_ids[item["category"]],
                title_en=item["title"],
                description_en=item["description"],
                material=item["material"],
                technique=item["technique"],
                seo_keywords=item["keywords"],
                price=item["price"],
                stock=0,
                status="published",
                ai_generated=False,
                published_at=sa.func.now(),
                idempotency_key=item["key"],
            )
            .returning(products.c.id)
        ).scalar_one()

        bind.execute(
            sa.insert(product_images).values(
                product_id=product_id,
                url=f"https://artisans-ten.vercel.app/categories/{item['image']}",
                is_primary=True,
                order_index=0,
            )
        )


def downgrade() -> None:
    bind = op.get_bind()
    metadata = sa.MetaData()
    users = sa.Table("users", metadata, autoload_with=bind)
    artisans = sa.Table("artisan_profiles", metadata, autoload_with=bind)
    products = sa.Table("products", metadata, autoload_with=bind)
    product_images = sa.Table("product_images", metadata, autoload_with=bind)

    keys = [item["key"] for item in PRODUCTS]
    product_ids = bind.execute(
        sa.select(products.c.id).where(products.c.idempotency_key.in_(keys))
    ).scalars().all()
    if product_ids:
        bind.execute(sa.delete(product_images).where(product_images.c.product_id.in_(product_ids)))
        bind.execute(sa.delete(products).where(products.c.id.in_(product_ids)))

    demo_email = "demo-catalog@kalasathi.invalid"
    user_id = bind.execute(
        sa.select(users.c.id).where(users.c.email == demo_email)
    ).scalar_one_or_none()
    if user_id is not None:
        bind.execute(sa.delete(artisans).where(artisans.c.user_id == user_id))
        bind.execute(sa.delete(users).where(users.c.id == user_id))

    # Keep the shared reference categories; they may be used by real artisan
    # listings created after this migration.
