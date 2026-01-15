# app/search/service.py
from typing import List, Optional
import meilisearch
from meilisearch.errors import MeilisearchError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.auth.models import USER_ID_T
from app.recipes.models import (
    FoodCandidate,
    Recipe,
    RecipeRevision,
    IngredientGroup,
    Ingredient,
)
from app.core.config import settings


class MeilisearchService:
    def __init__(self):
        self.client = meilisearch.Client(
            settings.MEILISEARCH_URL, settings.MEILISEARCH_MASTER_KEY
        )
        self.recipe_index_name = "recipes"
        self.food_index_name = "foods"
        self._setup_recipe_index()
        self._setup_food_index()

    def _setup_food_index(self):
        try:
            index = self.client.get_index(self.food_index_name)
        except MeilisearchError:
            # Create index if it doesn't exist
            task = self.client.create_index(self.food_index_name, {"primaryKey": "id"})
            self.client.wait_for_task(task.task_uid)
            index = self.client.get_index(self.food_index_name)

        # Configure searchable attributes with priority
        index.update_searchable_attributes(
            [
                "name",  # Highest priority
                "description",
            ]
        )

        # Configure filterable attributes for faceted search
        index.update_filterable_attributes(
            [
                "language",
            ]
        )
        #
        # # Configure sortable attributes
        # index.update_sortable_attributes(
        #     ["created_at", "updated_at", "difficulty", "prep_time", "cook_time"]
        # )

        # Configure ranking rules (title prioritization)
        index.update_ranking_rules(
            [
                "words",
                "typo",
                "proximity",
                "attribute",  # This uses searchable_attributes order
                "sort",
                "exactness",
            ]
        )

    def _setup_recipe_index(self):
        """Initialize Meilisearch index with proper configuration"""
        try:
            index = self.client.get_index(self.recipe_index_name)
        except MeilisearchError:
            # Create index if it doesn't exist
            self.client.create_index(self.recipe_index_name, {"primaryKey": "id"})
            index = self.client.get_index(self.recipe_index_name)

        # Configure searchable attributes with priority
        index.update_searchable_attributes(
            [
                "title",  # Highest priority
                "subtitle",
                "ingredients",  # Medium priority
                "instructions",  # Lower priority
                "categories",
                "owner_comment",
            ]
        )

        # Configure filterable attributes for faceted search
        index.update_filterable_attributes(
            [
                "language",
                "is_private",
                "is_draft",
                "owner_id",
                "difficulty",
                "categories",
                "prep_time",
                "cook_time",
                "servings",
            ]
        )

        # Configure sortable attributes
        index.update_sortable_attributes(
            ["created_at", "updated_at", "difficulty", "prep_time", "cook_time"]
        )

        # Configure ranking rules (title prioritization)
        index.update_ranking_rules(
            [
                "words",
                "typo",
                "proximity",
                "attribute",  # This uses searchable_attributes order
                "sort",
                "exactness",
            ]
        )

    async def index_recipe(self, recipe: Recipe, db: AsyncSession):
        """Index a single recipe"""
        # Load all relationships if not already loaded
        if not recipe.latest_revision:
            result = await db.execute(
                select(Recipe)
                .where(Recipe.id == recipe.id)
                .options(
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
            recipe = result.scalar_one()

        doc = self._recipe_to_document(recipe)
        index = self.client.get_index(self.recipe_index_name)
        index.add_documents([doc])

    async def index_recipes_bulk(self, recipes: List[Recipe]):
        """Bulk index multiple recipes"""
        documents = [self._recipe_to_document(recipe) for recipe in recipes]
        if documents:
            index = self.client.get_index(self.recipe_index_name)
            index.add_documents(documents)

    def _recipe_to_document(self, recipe: Recipe) -> dict:
        """Convert Recipe model to Meilisearch document"""
        revision = recipe.latest_revision

        # Extract all ingredients as flat list
        ingredients = []
        for group in revision.ingredient_groups:
            for ing in group.ingredients:
                ingredients.append(
                    f"{ing.food} ({ing.unit.name if ing.unit is not None else ''})"
                )

        # Extract all instructions
        instructions = []
        for group in revision.instruction_groups:
            instructions.append(group.instructions)

        # Extract category names
        categories = [cat.name for cat in revision.categories]

        return {
            "id": recipe.id,
            "title": revision.title,
            "subtitle": revision.subtitle,
            "ingredients": ingredients,
            "instructions": instructions,
            "categories": categories,
            "owner_comment": revision.owner_comment,
            "language": recipe.language,
            "is_private": recipe.is_private,
            "is_draft": recipe.is_draft,
            "owner_id": str(recipe.owner_id),
            "difficulty": revision.difficulty,
            "servings": revision.servings,
            "prep_time": revision.prep_time,
            "cook_time": revision.cook_time,
            "created_at": recipe.created_at.timestamp(),
            "updated_at": recipe.updated_at.timestamp(),
        }

    async def delete_recipe(self, recipe_id: int):
        """Remove recipe from index"""
        index = self.client.get_index(self.recipe_index_name)
        update = index.delete_document(recipe_id)

    async def index_food(self, food: FoodCandidate | str, db: AsyncSession):
        """Index a single food"""
        doc = self._food_to_document(food)
        index = self.client.get_index(self.food_index_name)
        index.add_documents([doc])

    async def index_food_bulk(self, foods: list[FoodCandidate] | list[str]):
        """Bulk index multiple recipes"""
        documents = [self._food_to_document(food) for food in foods]
        if documents:
            index = self.client.get_index(self.food_index_name)
            task = index.add_documents(documents)
            self.client.wait_for_task(task.task_uid)

    def _food_to_document(self, food: FoodCandidate | str) -> dict:
        """Convert Food model to Meilisearch document"""
        if isinstance(food, str):
            return {"name": food}
        else:
            return {
                "id": food.id,
                "name": food.name,
                "description": food.description,
                "language": food.language,
            }

    def search_recipes(
        self,
        query: str,
        languages: Optional[List[str]] = None,
        categories: Optional[List[str]] = None,
        difficulty: Optional[int] = None,
        owner_id: USER_ID_T = None,
        limit: int = 20,
        offset: int = 0,
        attributes_to_highlight: Optional[List[str]] = None,
    ) -> dict:
        """
        Search recipes with filters

        Returns Meilisearch response with hits, facets, etc.
        """
        index = self.client.get_index(self.recipe_index_name)

        # Build filter string
        filters = []

        if languages:
            lang_filter = " OR ".join([f'language = "{lang}"' for lang in languages])
            filters.append(f"({lang_filter})")

        if categories:
            cat_filter = " OR ".join([f'categories = "{cat}"' for cat in categories])
            filters.append(f"({cat_filter})")

        if difficulty is not None:
            filters.append(f"difficulty = {difficulty}")

        if owner_id is not None:
            filters.append(f"owner_id = {owner_id}")
        else:
            filters.append("is_private = false")

        filter_string = " AND ".join(filters) if filters else None

        # Search options
        search_params = {
            "limit": limit,
            "offset": offset,
            "filter": filter_string,
            "attributesToRetrieve": ["*"],
        }

        if attributes_to_highlight:
            search_params["attributesToHighlight"] = attributes_to_highlight
            search_params["highlightPreTag"] = "<mark>"
            search_params["highlightPostTag"] = "</mark>"

        return index.search(query, search_params)

    def search_foods(
        self,
        query: str,
        languages: Optional[List[str]] = None,
        limit: int = 20,
        offset: int = 0,
        attributes_to_highlight: Optional[List[str]] = None,
    ) -> dict:
        """
        Search recipes with filters

        Returns Meilisearch response with hits, facets, etc.
        """
        index = self.client.get_index(self.food_index_name)
        filters = []

        if languages:
            lang_filter = " OR ".join([f'language = "{lang}"' for lang in languages])
            filters.append(f"({lang_filter})")

        filter_string = " AND ".join(filters) if filters else None

        # Search options
        search_params = {
            "limit": limit,
            "offset": offset,
            "filter": filter_string,
            "attributesToRetrieve": ["*"],
        }

        if attributes_to_highlight:
            search_params["attributesToHighlight"] = attributes_to_highlight
            search_params["highlightPreTag"] = "<mark>"
            search_params["highlightPostTag"] = "</mark>"

        return index.search(query, search_params)


# Singleton instance
_meilisearch_service = None


def get_meilisearch_service() -> MeilisearchService:
    global _meilisearch_service
    if _meilisearch_service is None:
        _meilisearch_service = MeilisearchService()
    return _meilisearch_service
