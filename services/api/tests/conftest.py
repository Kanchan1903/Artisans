"""Pytest configuration and async test fixtures for KalaSathi API."""
import asyncio
import pytest
import pytest_asyncio
from httpx import AsyncClient, ASGITransport
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker

from app.database import Base, get_db
from app.models.product import Category
from app.main import app

# Use in-memory SQLite for super-fast, isolated testing
TEST_DATABASE_URL = "sqlite+aiosqlite:///:memory:"

test_engine = create_async_engine(
    TEST_DATABASE_URL,
    connect_args={"check_same_thread": False},
)

TestingSessionLocal = async_sessionmaker(
    test_engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False,
)


@pytest_asyncio.fixture(scope="session")
def event_loop():
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()


@pytest_asyncio.fixture(scope="function")
async def db_session():
    """Create a fresh database for each test function."""
    import app.models  # noqa: F401
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async with TestingSessionLocal() as session:
        # Pre-seed essential categories
        cat1 = Category(name="Handloom & Textiles", name_hi="हथकरघा और वस्त्र", slug="handloom")
        cat2 = Category(name="Pottery & Clay", name_hi="मिट्टी के बर्तन", slug="pottery")
        cat3 = Category(name="Tribal & Folk Art", name_hi="जनजातीय और लोक कला", slug="folk-art")
        session.add_all([cat1, cat2, cat3])
        await session.commit()
        yield session

    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)


@pytest_asyncio.fixture(scope="function")
async def client(db_session: AsyncSession):
    """Async HTTP test client with overridden database dependency."""
    async def override_get_db():
        yield db_session

    app.dependency_overrides[get_db] = override_get_db
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac
    app.dependency_overrides.clear()
