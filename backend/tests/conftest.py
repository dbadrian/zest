import asyncio
from collections.abc import AsyncGenerator
import pytest
from httpx import AsyncClient, ASGITransport
from sqlalchemy.ext.asyncio import AsyncSession

from app.main import app
from app.db import engine, get_db, AsyncSessionLocal
from app.core import config

# @pytest.fixture(scope="session")
# def event_loop():
#     """
#     Needed for pytest-asyncio when using session-scoped async fixtures
#     """
#     loop = asyncio.get_event_loop_policy().new_event_loop()
#     yield loop
#     loop.close()
#


@pytest.fixture(scope="session", autouse=True)
async def prepare_database():
    """
    Ensure DB schema exists once per test session.
    Lifespan already calls init_db(), but this protects
    against direct test imports.
    """
    # nothing needed if lifespan is enabled
    yield


@pytest.fixture
async def db_session() -> AsyncGenerator[AsyncSession, None]:
    """
    Creates a SAVEPOINT-based transactional session.
    Rolls back everything after each test.
    """
    async with engine.connect() as conn:
        transaction = await conn.begin()
        session = AsyncSession(bind=conn, expire_on_commit=False)

        try:
            yield session
        finally:
            await session.close()
            await transaction.rollback()


@pytest.fixture(autouse=True)
def override_get_db(db_session: AsyncSession):
    async def _get_db_override():
        try:
            yield db_session
            await db_session.flush()
        finally:
            pass  # rollback handled by fixture

    app.dependency_overrides[get_db] = _get_db_override
    yield
    app.dependency_overrides.clear()


@pytest.fixture
async def client():
    transport = ASGITransport(app=app)

    async with AsyncClient(
        transport=transport,
        base_url="http://test",
    ) as client:
        yield client
