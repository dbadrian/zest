"""
Just a helper tool for dev to create a new user from scratch manually and have an invite mail sent
"""

from argparse import ArgumentParser
import asyncio

from pydantic import EmailStr
from sqlalchemy import select

from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.auth.auth import register_user
from app.auth.schemas import UserRegister
from app.auth.models import User
from app.core.config import settings
from app.db import async_sessionmaker
from app.auth.models import User
import app.auth.security_utils as su


async def create_new_user(username: str, email: EmailStr):

    engine = create_async_engine(str(settings.SQLALCHEMY_DATABASE_URI), echo=False)
    async_session = async_sessionmaker(engine, expire_on_commit=False)

    async with async_session() as session:
        result = await session.execute(
            select(User).where(User.username == username or User.email == email)
        )
    #     user = result.scalar_one_or_none()

    #     if user:
    #         print("This user already exists")
    #         return


    #     # user_data = UserRegister(username=username, email=email, password=su.generate_high_entropy_token())
    #     # await register_user(user_data, db=session, request=None)


if __name__ == "__main__":
    parser = ArgumentParser()
    parser.add_argument("-u", "--username", required=True)
    parser.add_argument("-e", "--email", required=True)
    args = parser.parse_args()

    asyncio.run(create_new_user(args.username, args.email))
