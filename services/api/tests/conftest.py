"""Pytest configuration and async test fixtures for KalaSathi API."""
import asyncio
import pytest
import pytest_asyncio
import httpx
from httpx import AsyncClient, ASGITransport
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker

from app.database import Base, get_db
from app.models.product import Category
from app.main import app


@pytest.fixture(autouse=True)
def mock_agent_image_downloads(monkeypatch):
    """Return a valid in-memory JPEG for agent output URLs during API tests."""
    from app.utils import image_jobs
    from PIL import Image
    import io

    buffer = io.BytesIO()
    Image.new("RGB", (2, 2), color="white").save(buffer, format="JPEG")
    image_bytes = buffer.getvalue()

    def handler(request):
        return httpx.Response(200, headers={"content-type": "image/jpeg"}, content=image_bytes)

    monkeypatch.setattr(image_jobs, "image_output_transport_factory", lambda: httpx.MockTransport(handler))
    monkeypatch.setattr("app.utils.crewai_client.CrewAIClient.get_inputs", lambda self: _empty_inputs())

    async def mock_storage_upload(file_bytes, filename, content_type="image/jpeg"):
        return f"https://storage.example.test/uploads/{filename}"

    monkeypatch.setattr("app.utils.storage.storage.upload_file", mock_storage_upload)
    mongo_documents = {}

    class FakeCollection:
        async def update_one(self, query, update, upsert=False):
            key_name, key_value = next(iter(query.items()))
            document = mongo_documents.setdefault(key_value, {key_name: key_value})
            document.update(update.get("$set", {}))
            for key, value in update.get("$setOnInsert", {}).items():
                document.setdefault(key, value)

        async def find_one(self, query, projection=None):
            key_name, key_value = next(iter(query.items()))
            document = mongo_documents.get(key_value)
            if document and all(document.get(key) == value for key, value in query.items()):
                return dict(document)
            return None

        async def find_one_and_update(self, query, update, **kwargs):
            key_name, key_value = next(iter(query.items()))
            document = mongo_documents.get(key_value)
            if document and all(document.get(key) == value for key, value in query.items()):
                document.update(update.get("$set", {}))
                return dict(document)
            return None

    class FakeDatabase:
        def __getitem__(self, collection_name):
            return FakeCollection()

    monkeypatch.setattr("app.mongodb.get_mongo_database", lambda: FakeDatabase())


async def _empty_inputs():
    return []

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
