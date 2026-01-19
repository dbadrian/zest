"""
Just a helper tool for dev to quickly unlock a user via CLI
"""

import asyncio
from backend.app.auth.auth import reset_failed_attempts
from sqlalchemy import select

from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from tqdm import tqdm
from app.auth.models import User
from app.core.config import settings
from app.db import async_sessionmaker
from app.auth.models import User



async def unlock_user(username: str):

    engine = create_async_engine(str(settings.SQLALCHEMY_DATABASE_URI), echo=False)
    async_session = async_sessionmaker(engine, expire_on_commit=False)

    async with async_session() as session:
        result = await session.execute(
            select(User).where(User.username == username)
        )
        user = result.scalar_one_or_none()

        if not user:
            reset_failed_attempts(user, session)
            await session.commit()
            print("User unlocked.")
        else:
            print("User not found.")


if __name__ == "__main__":
    asyncio.run(unlock_user())
