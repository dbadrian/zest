"""
Run with: python -m app.scripts.index_recipes
"""

import asyncio
from itertools import batched
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from tqdm import tqdm
from app.auth.models import User
from app.core.config import settings
from app.db import async_sessionmaker
from app.recipes.models import (
    FoodCandidate,
    Recipe,
    RecipeRevision,
    IngredientGroup,
    Ingredient,
)
from app.recipes.search import get_meilisearch_service


async def index_all_recipes():
    search_service = get_meilisearch_service()

    engine = create_async_engine(str(settings.SQLALCHEMY_DATABASE_URI), echo=False)
    async_session = async_sessionmaker(engine, expire_on_commit=False)

    async with async_session() as session:
        result = await session.execute(
            select(Recipe).options(
                selectinload(Recipe.latest_revision).selectinload(
                    RecipeRevision.categories
                ),
                selectinload(Recipe.latest_revision)
                .selectinload(RecipeRevision.ingredient_groups)
                .selectinload(IngredientGroup.ingredients)
                .selectinload(Ingredient.unit),
                selectinload(Recipe.latest_revision).selectinload(
                    RecipeRevision.instruction_groups
                ),
            )
        )
        recipes = result.scalars().all()

        print(f"Indexing {len(recipes)} recipes...")
        await search_service.index_recipes_bulk(recipes)
        print("Done!")

        foods = await session.execute(select(FoodCandidate))
        foods = foods.scalars().all()
        print(f"Indexing {len(foods)} foods...")
        for chunk in tqdm(batched(foods, 10000)):
            await search_service.index_food_bulk(chunk)
        print("Done!")


if __name__ == "__main__":
    asyncio.run(index_all_recipes())
