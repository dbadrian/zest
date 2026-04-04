"""
Helper tool to create a new entry in any registered SQLAlchemy model interactively
with confirmation, enum support, and optional manual ID selection.
"""

import asyncio
from argparse import ArgumentParser
from sqlalchemy import inspect, select
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy.orm import declarative_base
from sqlalchemy.exc import IntegrityError
from sqlalchemy.types import Enum as SQLAlchemyEnum
from app.core.config import settings
from app.db import async_sessionmaker

# Import your models here
from app.recipes.models import Unit, RecipeCategories, FoodCandidate

# Base models registry
MODELS = {
    "Unit": Unit,
    "RecipeCategories": RecipeCategories,
}

async def get_next_id(session, model_class):
    """Fetch the next available ID from the table"""
    pk_column = inspect(model_class).primary_key[0]
    result = await session.execute(select(pk_column).order_by(pk_column.desc()).limit(1))
    last_id = result.scalar()
    return (last_id or 0) + 1

async def prompt_for_fields(session, model_class):
    """Prompt user for all fields, with enum support and optional manual ID"""
    mapper = inspect(model_class)
    values = {}

    # Handle ID field first if exists
    pk_column = mapper.primary_key[0] if mapper.primary_key else None
    if pk_column is not None and pk_column.autoincrement:
        # Ask user if they want to manually set ID
        next_id = await get_next_id(session, model_class)
        use_manual = input(f"Next available ID is {next_id}. Do you want to set a custom ID? [y/N]: ").strip().lower()
        if use_manual == "y":
            while True:
                val = input(f"Enter ID (must be integer >= 1): ").strip()
                if val.isdigit() and int(val) >= 1:
                    values[pk_column.name] = int(val)
                    break
                print("Invalid ID. Try again.")
        else:
            # let database handle ID (do not add to values)
            pass

    for column in mapper.columns:
        # Skip PK if already handled
        if pk_column is not None and column.name == pk_column.name:
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

        # Required fields
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

    engine = create_async_engine(str(settings.SQLALCHEMY_DATABASE_URI), echo=False)
    async_session = async_sessionmaker(engine, expire_on_commit=False)

    async with async_session() as session:
        data = await prompt_for_fields(session, model_class)
        display_summary(model_name, data)

        confirm = input("Do you want to save this entry? [y/N]: ").strip().lower()
        if confirm != "y":
            print("Entry creation canceled.")
            return

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