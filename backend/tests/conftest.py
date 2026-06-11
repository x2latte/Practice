import asyncio
import pytest
import pytest_asyncio
from httpx import AsyncClient, ASGITransport
from sqlalchemy.pool import NullPool
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from app.main import app
from app.database import Base
from app.dependencies import get_db
import os
from dotenv import load_dotenv

# Load .env and .app_config files if they exist in the backend or root folder
backend_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
project_root = os.path.dirname(backend_root)

load_dotenv(".env", override=True)
load_dotenv(".app_config", override=True)
load_dotenv(os.path.join(backend_root, ".env"), override=True)
load_dotenv(os.path.join(backend_root, ".app_config"), override=True)
load_dotenv(os.path.join(project_root, ".env"), override=True)
load_dotenv(os.path.join(project_root, ".app_config"), override=True)

db_uri_env = os.getenv("DB_URI") or os.getenv("DATABASE_URL")

if db_uri_env:
    # If the database URL is provided but does not contain "test", safely map
    # it to the test database name to avoid running tests on development database data.
    if "test" not in db_uri_env:
        base, db_name = db_uri_env.rsplit("/", 1)
        if "?" in db_name:
            main_db, query = db_name.split("?", 1)
            test_db = "ras_test" if main_db == "ras_db" else f"{main_db}_test"
            TEST_DB_URL = f"{base}/{test_db}?{query}"
        else:
            test_db = "ras_test" if db_name == "ras_db" else f"{db_name}_test"
            TEST_DB_URL = f"{base}/{test_db}"
    else:
        TEST_DB_URL = db_uri_env
else:
    TEST_DB_URL = "postgresql+asyncpg://tzuser:tzpass@localhost:5432/tz_db_test"

test_engine = create_async_engine(TEST_DB_URL, echo=False, poolclass=NullPool)
TestSession  = async_sessionmaker(test_engine, expire_on_commit=False)


@pytest_asyncio.fixture
async def setup_db():
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
        await conn.run_sync(Base.metadata.create_all)
    yield
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
    await test_engine.dispose()


@pytest_asyncio.fixture(autouse=True)
async def clean_db(setup_db):
    yield


@pytest_asyncio.fixture
async def db_session(setup_db):
    async with TestSession() as session:
        yield session
        await session.rollback()


@pytest_asyncio.fixture
async def client():
    async def override_get_db():
        async with TestSession() as session:
            yield session
    app.dependency_overrides[get_db] = override_get_db
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        yield c
    app.dependency_overrides.clear()

@pytest.fixture(autouse=True)
async def clean_db_all(db_session):
    yield
    # Откат транзакции, чтобы тесты не влияли друг на друга
    await db_session.rollback()
    # Очистка всех таблиц (для тестовой БД)
    from app.models import User, Project, RefreshToken, File  # добавьте свои модели
    for table in [RefreshToken, User, Project, File]:
        await db_session.execute(table.__table__.delete())
    await db_session.commit()

@pytest.fixture(autouse=True)
async def clean_db_all(db_session):
    yield
    # Откат транзакции, чтобы тесты не влияли друг на друга
    await db_session.rollback()
    # Очистка всех таблиц (для тестовой БД)
    from app.models import User, Project, RefreshToken, File  # добавьте свои модели
    for table in [RefreshToken, User, Project, File]:
        await db_session.execute(table.__table__.delete())
    await db_session.commit()
