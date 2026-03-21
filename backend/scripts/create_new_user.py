"""
Just a helper tool for dev to create a new user from scratch manually and have an invite mail sent
"""

from argparse import ArgumentParser
import asyncio
import secrets
import string

from pydantic import EmailStr
from sqlalchemy import select

from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from app.auth.auth import register_user
from app.auth.schemas import UserRegister
from app.recipes.models import Recipe
from app.auth.models import User
from app.core.config import settings
from app.db import async_sessionmaker
from app.auth.models import User
import app.auth.security_utils as su

def generate_password(length=16):
    if length < 4:
        raise ValueError("Password length must be at least 4")

    upper = string.ascii_uppercase
    lower = string.ascii_lowercase
    digits = string.digits
    special = string.punctuation

    # Ensure at least one from each category
    password_chars = [
        secrets.choice(upper),
        secrets.choice(lower),
        secrets.choice(digits),
        secrets.choice(special),
    ]

    # Fill the rest from all allowed characters
    all_chars = upper + lower + digits + special
    password_chars += [secrets.choice(all_chars) for _ in range(length - 4)]

    # Shuffle securely
    secrets.SystemRandom().shuffle(password_chars)

    return ''.join(password_chars)

async def create_new_user(username: str, email: EmailStr):

    engine = create_async_engine(str(settings.SQLALCHEMY_DATABASE_URI), echo=False)
    async_session = async_sessionmaker(engine, expire_on_commit=False)

    async with async_session() as session:
        result = await session.execute(
            select(User).where(User.username == username or User.email == email)
        )
        user = result.scalar_one_or_none()

        if user:
            print("This user already exists")
            return

        user_data = UserRegister(username=username, email=email, password=generate_password())
        ret = await register_user(user_data, db=session, request=None, manual_user_creation=True)
        await session.commit()

if __name__ == "__main__":
    parser = ArgumentParser()
    parser.add_argument("-u", "--username", required=True)
    parser.add_argument("-e", "--email", required=True)
    args = parser.parse_args()

    asyncio.run(create_new_user(args.username, args.email))
