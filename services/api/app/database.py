"""Async SQLAlchemy engine, session factory, and database initialization."""
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase
from app.config import settings

engine_kwargs = {
    "echo": False,
    "pool_pre_ping": True,
}

# Only pass connection pool sizes for non-SQLite databases
if "sqlite" not in settings.async_database_url:
    engine_kwargs["pool_size"] = 10
    engine_kwargs["max_overflow"] = 20

engine = create_async_engine(
    settings.async_database_url,
    **engine_kwargs,
)

AsyncSessionLocal = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False,
)


class Base(DeclarativeBase):
    pass


async def get_db():
    """FastAPI dependency that yields a DB session."""
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


async def init_db():
    """Create all tables in the database if they don't already exist."""
    global engine, AsyncSessionLocal
    # Import all models to ensure they are registered with Base.metadata
    import app.models  # noqa: F401
    def _apply_compatibility_migrations(connection):
        from sqlalchemy import inspect, text

        # create_all() creates missing tables but never adds new columns to an
        # existing PostgreSQL/SQLite table. Older local databases therefore
        # need this idempotent compatibility addition for password sign-up.
        tables = set(inspect(connection).get_table_names())
        if "users" in tables:
            user_columns = {
                column["name"] for column in inspect(connection).get_columns("users")
            }
            if "password_hash" not in user_columns:
                connection.execute(
                    text("ALTER TABLE users ADD COLUMN password_hash VARCHAR(255)")
                )

        try:
            connection.execute(text("ALTER TABLE products ADD COLUMN idempotency_key TEXT"))
        except Exception:
            pass
        try:
            connection.execute(text("ALTER TABLE orders ADD COLUMN payment_status VARCHAR(50) DEFAULT 'unpaid'"))
        except Exception:
            pass
        try:
            connection.execute(text("ALTER TABLE product_images ADD COLUMN upload_key VARCHAR(64)"))
        except Exception:
            pass
        try:
            connection.execute(text("CREATE UNIQUE INDEX IF NOT EXISTS ix_product_images_upload_key ON product_images (upload_key)"))
        except Exception:
            pass

        # Seed 5 distinct starter products if the product table is empty or contains legacy demo duplicates
        try:
            # Check if existing products are only legacy pottery duplicates
            pottery_dupes = connection.execute(
                text("SELECT count(*) FROM products WHERE title_en = 'Clay Pot' OR title_en = 'Have Made This Mobile Cover'")
            ).scalar() or 0
            if pottery_dupes > 0:
                connection.execute(text("DELETE FROM product_images WHERE product_id IN (SELECT id FROM products WHERE title_en = 'Clay Pot' OR title_en = 'Have Made This Mobile Cover')"))
                connection.execute(text("DELETE FROM products WHERE title_en = 'Clay Pot' OR title_en = 'Have Made This Mobile Cover'"))

            prod_count = connection.execute(text("SELECT count(*) FROM products")).scalar() or 0
            if prod_count == 0:
                # Ensure master artisan exists
                user_id = connection.execute(
                    text("SELECT id FROM users WHERE email = 'master-artisan@kalasathi.org'")
                ).scalar()
                if not user_id:
                    user_res = connection.execute(
                        text("INSERT INTO users (email, phone, full_name, preferred_language, is_active) VALUES ('master-artisan@kalasathi.org', '+919876543210', 'Master Craftsman of India', 'en', true) RETURNING id")
                    )
                    user_id = user_res.scalar()

                artisan_id = connection.execute(
                    text(f"SELECT id FROM artisan_profiles WHERE user_id = {user_id}")
                ).scalar()
                if not artisan_id:
                    art_res = connection.execute(
                        text(f"INSERT INTO artisan_profiles (user_id, name, craft_type, village, district, state, bio, is_approved, years_experience) VALUES ({user_id}, 'Master Artisan Guild', 'Heritage Crafts & Decor', 'Shilpgram', 'Udaipur', 'Rajasthan', 'National heritage award-winning cooperative of master artisans practicing India ancient handicrafts.', true, 25) RETURNING id")
                    )
                    artisan_id = art_res.scalar()

                # Get category map
                cat_rows = connection.execute(text("SELECT id, slug FROM categories")).fetchall()
                cat_map = {row[1]: row[0] for row in cat_rows}

                starter_items = [
                    (
                        "demo-handcrafted-blue-pottery-vase",
                        cat_map.get("pottery"),
                        "Handcrafted Jaipur Blue Pottery Floral Vase",
                        "Authentic Jaipur blue pottery vase handcrafted using traditional quartz powder and natural mineral dyes. Adorned with intricate Persian-inspired floral motifs, this glazed decorative vase adds an exquisite heritage aesthetic to any home or office.",
                        "Quartz stone powder, glass powder, natural blue dye",
                        "Hand-molded Jaipur glazed blue pottery",
                        849.0,
                        "https://images.unsplash.com/photo-1578749556568-bc2c40e68b61?auto=format&fit=crop&w=800&q=80",
                    ),
                    (
                        "demo-handcarved-wooden-elephant",
                        cat_map.get("woodcraft"),
                        "Handcarved Sheesham Wood Royal Elephant",
                        "Magnificent decorative elephant figurine carved from a single block of seasoned Indian Sheesham wood. Features traditional jali lattice work and ornate festive engravings, finished in a smooth natural beeswax polish.",
                        "Solid Sheesham (Rosewood)",
                        "Hand chiseled and openwork lattice carving",
                        1299.0,
                        "https://images.unsplash.com/photo-1606744837616-56c9a5c6a6eb?auto=format&fit=crop&w=800&q=80",
                    ),
                    (
                        "demo-tribal-warli-folk-canvas-art",
                        cat_map.get("folk-art"),
                        "Traditional Warli Tribal Canvas Painting",
                        "Captivating Warli tribal folk art depicting the sacred Tarpa celebration and village harvest rhythm. Handpainted on treated earthen-textured canvas using traditional rice paste medium and natural gum bind.",
                        "Cotton canvas, rice flour paste, red ochre base",
                        "Traditional Warli geometric stick painting",
                        699.0,
                        "https://images.unsplash.com/photo-1579783902614-a3fb3927b675?auto=format&fit=crop&w=800&q=80",
                    ),
                    (
                        "demo-chanderi-handloom-dupatta",
                        cat_map.get("handloom"),
                        "Pure Chanderi Silk Zari Woven Dupatta",
                        "Feather-light Chanderi silk dupatta lovingly handwoven on traditional pit looms by heritage weavers. Decorated with fine golden metallic zari borders and timeless floral buti motifs, ideal for festive celebrations.",
                        "Pure Chanderi silk and gold zari thread",
                        "Pit loom handloom weaving",
                        1499.0,
                        "https://images.unsplash.com/photo-1610030469983-98e550d6193c?auto=format&fit=crop&w=800&q=80",
                    ),
                    (
                        "demo-dhokra-brass-tribal-necklace",
                        cat_map.get("jewelry"),
                        "Dhokra Lost-Wax Cast Brass Tribal Choker",
                        "Ancient 4000-year-old lost-wax cast brass jewelry piece crafted by tribal artisans in Bastar. Features geometric tubular beads, antique brass patina, and hand-braided adjustable cotton cord for comfortable wear.",
                        "Recycled brass, terracotta mold, waxed cotton cord",
                        "Cire perdue (Lost-wax metal casting)",
                        950.0,
                        "https://images.unsplash.com/photo-1599643478518-a784e5dc4c8f?auto=format&fit=crop&w=800&q=80",
                    ),
                ]

                for key, c_id, title, desc, mat, tech, price, img_url in starter_items:
                    c_id_val = f"{c_id}" if c_id else "NULL"
                    p_res = connection.execute(
                        text(
                            f"INSERT INTO products (artisan_id, category_id, title_en, description_en, material, technique, price, stock, status, processing_status, ai_generated, published_at, idempotency_key, created_at, updated_at) "
                            f"VALUES ({artisan_id}, {c_id_val}, '{title}', '{desc}', '{mat}', '{tech}', {price}, 15, 'published', 'completed', false, NOW(), '{key}', NOW(), NOW()) RETURNING id"
                        )
                    )
                    new_pid = p_res.scalar()
                    connection.execute(
                        text(
                            f"INSERT INTO product_images (product_id, url, is_primary, order_index, created_at) "
                            f"VALUES ({new_pid}, '{img_url}', true, 0, NOW())"
                        )
                    )
        except Exception as e:
            import logging
            logging.getLogger("database").warning("Error during starter crafts seeding: %s", e)

    try:
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
            await conn.run_sync(_apply_compatibility_migrations)
    except Exception as e:
        if "sqlite" not in settings.async_database_url:
            import logging
            logging.getLogger("database").warning(
                "PostgreSQL connection unavailable (%s). Falling back to SQLite (kalasathi.db)...", e
            )
            settings.DATABASE_URL = "sqlite+aiosqlite:///./kalasathi.db"
            engine = create_async_engine(settings.async_database_url, echo=False)
            AsyncSessionLocal = async_sessionmaker(
                engine,
                class_=AsyncSession,
                expire_on_commit=False,
                autocommit=False,
                autoflush=False,
            )
            async with engine.begin() as conn:
                await conn.run_sync(Base.metadata.create_all)
                await conn.run_sync(_apply_compatibility_migrations)
        else:
            raise
