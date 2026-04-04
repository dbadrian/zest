"""
Helper tool to create a new entry in any registered SQLAlchemy model interactively
with confirmation before saving.
"""

import asyncio
from argparse import ArgumentParser
from sqlalchemy import inspect
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy.orm import declarative_base
from sqlalchemy.exc import IntegrityError
from sqlalchemy.types import Enum as SQLAlchemyEnum

from app.core.config import settings
from app.db import async_sessionmaker

# Import all your models here
from app.recipes.models import Unit, RecipeCategories, FoodCandidate

# Base models registry
MODELS = {
    "Unit": Unit,
    "RecipeCategories": RecipeCategories,
    "FoodCandidate": FoodCandidate,
}

async def prompt_for_fields(model_class):
    """Prompt user to fill all NOT NULL fields except auto-increment PKs, with enum support"""
    mapper = inspect(model_class)
    values = {}

    for column in mapper.columns:
        # Skip auto-generated primary keys
        if column.primary_key and column.autoincrement:
            continue

        # Handle Enum fields
        if isinstance(column.type, SQLAlchemyEnum):
            enum_values = column.type.enums
            while True:
                val = input(f"Enter value for {column.name} ({column.type}) [options: {', '.join(enum_values)}]: ").strip()
                if val in enum_values:
                    values[column.name] = val
                    break
                else:
                    print(f"Invalid choice. Please choose from: {', '.join(enum_values)}")
            continue

        # Handle NOT NULL fields
        if not column.nullable and column.default is None:
            while True:
                val = input(f"Enter value for {column.name} ({column.type}): ").strip()
                if val:
                    values[column.name] = val
                    break
        else:
            val = input(f"Enter value for {column.name} ({column.type}) [optional]: ").strip()
            values[column.name] = val if val else None

    return values

def display_summary(model_name, data):
    """Display a summary of the entered data for confirmation"""
    print("\nSummary of the new entry:")
    print(f"Model: {model_name}")
    print("-" * 30)
    for field, value in data.items():
        print(f"{field}: {value}")
    print("-" * 30)

async def create_entry(model_name):
    model_class = MODELS.get(model_name)
    if model_class is None:
        print(f"Model {model_name} not found.")
        return

    data = await prompt_for_fields(model_class)
    display_summary(model_name, data)

    # Ask for confirmation
    confirm = input("Do you want to save this entry? [y/N]: ").strip().lower()
    if confirm != "y":
        print("Entry creation canceled.")
        return

    engine = create_async_engine(str(settings.SQLALCHEMY_DATABASE_URI), echo=False)
    async_session = async_sessionmaker(engine, expire_on_commit=False)

    async with async_session() as session:
        instance = model_class(**data)
        session.add(instance)
        try:
            await session.commit()
            print(f"{model_name} entry created successfully!")
        except IntegrityError as e:
            await session.rollback()
            print(f"Failed to create {model_name}: {e}")

if __name__ == "__main__":
    parser = ArgumentParser()
    parser.add_argument(
        "-m", "--model", required=True, choices=list(MODELS.keys()),
        help="The SQLAlchemy model to create a new entry for"
    )
    args = parser.parse_args()

    asyncio.run(create_entry(args.model))