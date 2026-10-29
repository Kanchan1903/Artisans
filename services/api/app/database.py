"""Async SQLAlchemy engine, session factory, and database initialization."""
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase
from app.config import settings

engine_kwargs = {
    "echo": False,
    "pool_pre_ping": True,
}

# Only pass connection pool sizes for non-SQLite databases
if "sqlite" not in settings.DATABASE_URL:
    engine_kwargs["pool_size"] = 10
    engine_kwargs["max_overflow"] = 20

engine = create_async_engine(
    settings.DATABASE_URL,
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
    def _apply_sqlite_migrations(connection):
        from sqlalchemy import text
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

    try:
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
            await conn.run_sync(_apply_sqlite_migrations)
    except Exception as e:
        if "sqlite" not in settings.DATABASE_URL:
            import logging
            logging.getLogger("database").warning(
                "PostgreSQL connection unavailable (%s). Falling back to SQLite (kalasathi.db)...", e
            )
            settings.DATABASE_URL = "sqlite+aiosqlite:///./kalasathi.db"
            engine = create_async_engine(settings.DATABASE_URL, echo=False)
            AsyncSessionLocal = async_sessionmaker(
                engine,
                class_=AsyncSession,
                expire_on_commit=False,
                autocommit=False,
                autoflush=False,
            )
            async with engine.begin() as conn:
                await conn.run_sync(Base.metadata.create_all)
                await conn.run_sync(_apply_sqlite_migrations)
        else:
            raise
