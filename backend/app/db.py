from typing import AsyncGenerator
from contextlib import asynccontextmanager

from sqlalchemy import select
from sqlalchemy.ext.asyncio import (
    create_async_engine,
    async_sessionmaker,
    AsyncSession,
    AsyncEngine,
)
from sqlalchemy.orm import DeclarativeBase

from app.core.config import settings

# Create async engine with recommended settings
engine: AsyncEngine = create_async_engine(
    settings.SQLALCHEMY_DATABASE_URI.unicode_string(),
    echo=(settings.ENVIRONMENT != "production"),  # Set to False in production
    future=True,  # Use SQLAlchemy 2.0 style
    pool_pre_ping=True,  # Verify connections before using
)

# Create async session factory
# expire_on_commit=False prevents accessing expired attributes after commit
AsyncSessionLocal = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False,
)


class Base(DeclarativeBase):
    """Base class for all SQLAlchemy models using 2.0 declarative style"""

    pass


async def init_db() -> None:
    import app.auth.security_utils as su
    from app.auth.models import User

    async with AsyncSessionLocal() as session:
        result = await session.execute(
            select(User).where(User.email == settings.FIRST_SUPERUSER)
        )
        user = result.scalar_one_or_none()

        if not user:
            user_new = User(
                username=settings.FIRST_SUPERUSER,
                email=settings.FIRST_SUPERUSER,
                hashed_password=su.hash_password(settings.FIRST_SUPERUSER_PASSWORD),
                is_superuser=True,
                email_verified=True,
                is_active=True,
            )
            session.add(user_new)
            await session.commit()
        else:
            # todo user logger
            print("Super user already created.")


async def close_db() -> None:
    """Close database connections"""
    await engine.dispose()


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """
    Dependency that provides a database session.
    Automatically handles session lifecycle and cleanup.

    Usage:
        @app.get("/endpoint")
        async def endpoint(db: AsyncSession = Depends(get_db)):
            ...
    """
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Lifespan context manager for FastAPI application.
    Handles startup and shutdown events.
    """
    # Startup: Initialize database
    print("Starting up: Initializing database...")
    await init_db()

    yield

    # Shutdown: Close database connections
    print("Shutting down: Closing database connections...")
    await close_db()
