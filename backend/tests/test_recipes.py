import asyncio
from time import strptime
import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import datetime, UTC, timedelta

from app.core.config import settings
from app.recipes.models import (
    Recipe,
    RecipeRevision,
    RecipeCategories,
    Unit,
    FoodCandidate,
    IngredientGroup,
    Ingredient,
    InstructionGroup,
)
from app.auth.models import User
from app.recipes.constants import UnitSystem, BaseUnit
from app.auth.auth import get_current_user
from app.main import app

from app.db import init_db


@pytest.fixture(scope="function", autouse=True)
async def prepare_database():
    # call your async DB init
    await init_db()
    yield


# ============================================================================
# FIXTURES - AUTHENTICATION
# ============================================================================


@pytest.fixture(scope="function", autouse=True)
async def prepare_database():
    # call your async DB init
    await init_db()
    yield


@pytest.fixture
async def test_user(db_session: AsyncSession) -> User:
    """Create a test user in the database"""
    user = User(
        email="testuser@example.com",
        username="testuser@example.com",
        hashed_password="$2b$12$fakehashfortest",  # Adjust based on your User model
        # Add any other required fields for your User model
    )
    db_session.add(user)
    await db_session.flush()
    await db_session.refresh(user)
    return user


@pytest.fixture
async def other_user(db_session: AsyncSession) -> User:
    """Create another test user in the database"""
    user = User(
        username="otheruser@example.com",
        email="otheruser@example.com",
        hashed_password="$2b$12$fakehashfortest",
    )
    db_session.add(user)
    await db_session.flush()
    await db_session.refresh(user)
    return user


@pytest.fixture
def override_current_user(test_user: User):
    """Override the get_current_user dependency to return test_user"""

    async def _get_current_user_override():
        return test_user

    app.dependency_overrides[get_current_user] = _get_current_user_override
    yield test_user
    # Cleanup happens in conftest.py's autouse fixture


@pytest.fixture
def override_current_user_other(other_user: User):
    """Override the get_current_user dependency to return other_user"""

    async def _get_current_user_override():
        return other_user

    app.dependency_overrides[get_current_user] = _get_current_user_override
    yield other_user


def _add_minimal_ingredient(group: IngredientGroup, unit_id: int):
    Ingredient(
        food="Test Ingredient",
        amount_min=1.0,
        amount_max=None,
        unit_id=unit_id,
        position=0,
        ingredient_group=group,
    )


# ============================================================================
# FIXTURES - REFERENCE DATA
# ============================================================================


@pytest.fixture
async def categories(db_session: AsyncSession) -> list[RecipeCategories]:
    """Create test categories in the database"""
    cats = [
        RecipeCategories(name="Dessert"),
        RecipeCategories(name="Main Course"),
        RecipeCategories(name="Appetizer"),
    ]
    for cat in cats:
        db_session.add(cat)
    await db_session.flush()
    for cat in cats:
        await db_session.refresh(cat)
    return cats


@pytest.fixture
async def units(db_session: AsyncSession) -> list[Unit]:
    """Create test units in the database"""
    unit_list = [
        Unit(
            name="cup",
            base_unit=BaseUnit.LITER,
            conversion_factor=240.0,
            unit_system=UnitSystem.IMPERIAL,
        ),
        Unit(
            name="gram",
            base_unit=BaseUnit.KILOGRAM,
            conversion_factor=1.0,
            unit_system=UnitSystem.METRIC,
        ),
        Unit(
            name="piece",
            base_unit=None,
            conversion_factor=None,
            unit_system=UnitSystem.DIMENSIONLESS,
        ),
    ]
    for unit in unit_list:
        db_session.add(unit)
    await db_session.flush()
    for unit in unit_list:
        await db_session.refresh(unit)
    return unit_list


@pytest.fixture
async def food_candidates(db_session: AsyncSession) -> list[FoodCandidate]:
    """Create test food candidates in the database"""
    foods = [
        FoodCandidate(
            name="Flour",
            description="All-purpose flour",
            language="en",
        ),
        FoodCandidate(
            name="Sugar",
            description="White granulated sugar",
            language="en",
        ),
        FoodCandidate(
            name="Butter",
            description="Unsalted butter",
            language="en",
        ),
    ]
    for food in foods:
        db_session.add(food)
    await db_session.flush()
    for food in foods:
        await db_session.refresh(food)
    return foods


@pytest.fixture
def sample_recipe_data(categories: list[RecipeCategories], units: list[Unit]) -> dict:
    """Sample recipe creation data"""
    return {
        "is_private": False,
        "is_draft": False,
        "language": "en",
        "content": {
            "title": "Chocolate Chip Cookies",
            "subtitle": "Classic homemade cookies",
            "difficulty": 2,
            "servings": 24,
            "prep_time": 15,
            "cook_time": 12,
            "source_name": "Grandma's Recipe Book",
            "source_page": "42",
            "source_url": "https://example.com/recipe",
            "owner_comment": "Family favorite!",
            "categories": [cat.id for cat in categories[:2]],
            "ingredient_groups": [
                {
                    "name": "Dry Ingredients",
                    "ingredients": [
                        {
                            "food": "Flour",
                            "amount_min": 2.5,
                            "amount_max": None,
                            "unit_id": units[0].id,
                            "comment": None,
                        },
                        {
                            "food": "Sugar",
                            "amount_min": 1.0,
                            "amount_max": 1.5,
                            "unit_id": units[0].id,
                            "comment": "A comment",
                        },
                    ],
                },
                {
                    "name": "Wet Ingredients",
                    "ingredients": [
                        {
                            "food": "Butter",
                            "amount_min": 200.0,
                            "amount_max": None,
                            "unit_id": units[1].id,
                            "comment": None,
                        },
                    ],
                },
            ],
            "instruction_groups": [
                {
                    "name": "Preparation",
                    "instructions": "Preheat oven to 350°F. Mix dry ingredients.",
                },
                {
                    "name": "Baking",
                    "instructions": "Bake for 10-12 minutes until golden.",
                },
            ],
        },
    }


# ============================================================================
# FIXTURES - RECIPES
# ============================================================================


@pytest.fixture
async def test_recipe(
    db_session: AsyncSession,
    test_user: User,
    categories: list[RecipeCategories],
    units: list[Unit],
) -> Recipe:
    """Create a test recipe in the database"""
    recipe = Recipe(
        owner_id=test_user.id,
        is_private=False,
        is_draft=False,
        language="en",
        created_at=datetime.now(UTC),
    )

    revision = RecipeRevision(
        recipe=recipe,
        title="Test Recipe",
        subtitle="A test recipe",
        difficulty=1,
        servings=4,
        prep_time=10,
        cook_time=20,
        categories=[categories[0]],
        created_at=datetime.now(UTC),
    )

    ingredient_group = IngredientGroup(
        name="Main Ingredients",
        position=0,
        recipe_revision=revision,
    )

    ingredient = Ingredient(
        food="Test Food",
        amount_min=1.0,
        amount_max=None,
        unit_id=units[0].id,
        comment="a test comment",
        position=0,
        ingredient_group=ingredient_group,
    )

    instruction_group = InstructionGroup(
        name="Instructions",
        instructions="Test instructions",
        position=0,
        recipe_revision=revision,
    )

    recipe.latest_revision = revision

    db_session.add(recipe)
    await db_session.flush()
    await db_session.refresh(recipe)

    return recipe


@pytest.fixture
async def private_recipe(
    db_session: AsyncSession,
    other_user: User,
    categories: list[RecipeCategories],
    units: list[Unit],
) -> Recipe:
    """Create a private recipe owned by other_user in the database"""
    recipe = Recipe(
        owner_id=other_user.id,
        is_private=True,
        is_draft=False,
        language="en",
        created_at=datetime.now(UTC),
    )

    revision = RecipeRevision(
        recipe=recipe,
        title="Private Recipe",
        subtitle="A private recipe",
        difficulty=3,
        servings=2,
        prep_time=30,
        cook_time=45,
        categories=[categories[1]],
        created_at=datetime.now(UTC),
    )

    ingredient_group = IngredientGroup(
        name="Ingredients",
        position=0,
        recipe_revision=revision,
    )

    ingredient = Ingredient(
        food="Secret Ingredient",
        amount_min=100.0,
        amount_max=None,
        unit_id=units[1].id,
        comment=None,
        position=0,
        ingredient_group=ingredient_group,
    )

    instruction_group = InstructionGroup(
        name="Steps",
        instructions="Secret instructions",
        position=0,
        recipe_revision=revision,
    )

    recipe.latest_revision = revision

    db_session.add(recipe)
    await db_session.flush()
    await db_session.refresh(recipe)

    return recipe


@pytest.fixture
async def draft_recipe(
    db_session: AsyncSession,
    other_user: User,
    categories: list[RecipeCategories],
    units: list[Unit],
) -> Recipe:
    """Create a draft recipe owned by other_user in the database"""
    recipe = Recipe(
        owner_id=other_user.id,
        is_private=False,
        is_draft=True,
        language="en",
        created_at=datetime.now(UTC),
    )

    revision = RecipeRevision(
        recipe=recipe,
        title="Private Recipe",
        subtitle="A private recipe",
        difficulty=3,
        servings=2,
        prep_time=30,
        cook_time=45,
        categories=[categories[1]],
        created_at=datetime.now(UTC),
    )

    ingredient_group = IngredientGroup(
        name="Ingredients",
        position=0,
        recipe_revision=revision,
    )

    ingredient = Ingredient(
        food="Secret Ingredient",
        amount_min=100.0,
        amount_max=None,
        unit_id=units[1].id,
        comment=None,
        position=0,
        ingredient_group=ingredient_group,
    )

    instruction_group = InstructionGroup(
        name="Steps",
        instructions="Secret instructions",
        position=0,
        recipe_revision=revision,
    )

    recipe.latest_revision = revision

    db_session.add(recipe)
    await db_session.flush()
    await db_session.refresh(recipe)

    return recipe


# ============================================================================
# INTEGRATION TESTS
# ============================================================================


class TestGetUnits:
    """Integration tests for GET /recipes/units"""

    @pytest.mark.anyio
    async def test_get_units_success(
        self,
        client: AsyncClient,
        override_current_user: User,
        units: list[Unit],
    ):
        """Should return all units from the database"""
        response = await client.get(f"{settings.API_V1_STR}/recipes/units")

        assert response.status_code == 200
        data = response.json()
        assert len(data["results"]) >= 3
        assert data["pagination"]["total"] >= 3

        # Verify the units we created are in the response
        unit_names = [u["name"] for u in data["results"]]
        assert "cup" in unit_names
        assert "gram" in unit_names
        assert "piece" in unit_names

    @pytest.mark.anyio
    async def test_get_units_empty_db(
        self,
        client: AsyncClient,
        override_current_user: User,
    ):
        """Should return empty list when no units exist"""
        response = await client.get(f"{settings.API_V1_STR}/recipes/units")

        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, dict)
        assert len(data["results"]) == 0


class TestGetFoods:
    """Integration tests for GET /recipes/foods"""

    @pytest.mark.anyio
    async def test_get_foods_success(
        self,
        client: AsyncClient,
        override_current_user: User,
        food_candidates: list[FoodCandidate],
        db_session: AsyncSession,
    ):
        """Should return paginated food candidates from database"""
        response = await client.get(f"{settings.API_V1_STR}/recipes/foods")

        assert response.status_code == 200
        data = response.json()
        assert "results" in data
        assert len(data["results"]) >= 3

        # Verify our test foods are in the response
        food_names = [f["name"] for f in data["results"]]
        assert "Flour" in food_names
        assert "Sugar" in food_names
        assert "Butter" in food_names

    @pytest.mark.anyio
    async def test_get_foods_pagination(
        self,
        client: AsyncClient,
        override_current_user: User,
        food_candidates: list[FoodCandidate],
    ):
        """Should support pagination parameters"""
        response = await client.get(
            f"{settings.API_V1_STR}/recipes/foods?page=1&page_size=2"
        )

        assert response.status_code == 200
        data = response.json()
        assert data["pagination"]["current_page"] == 1
        assert data["pagination"]["page_size"] == 2
        assert data["pagination"]["total_pages"] == 2
        assert len(data["results"]) == 2


class TestGetCategories:
    """Integration tests for GET /recipes/categories"""

    @pytest.mark.anyio
    async def test_get_categories_success(
        self,
        client: AsyncClient,
        override_current_user: User,
        categories: list[RecipeCategories],
    ):
        """Should return all categories from database"""
        response = await client.get(f"{settings.API_V1_STR}/recipes/categories")

        assert response.status_code == 200
        data = response.json()
        assert len(data["results"]) >= 3
        assert data["pagination"]["total"] >= 3

        category_names = [c["name"] for c in data["results"]]
        assert "Dessert" in category_names
        assert "Main Course" in category_names
        assert "Appetizer" in category_names


class TestGetRecipes:
    """Integration tests for GET /recipes"""

    @pytest.mark.anyio
    async def test_get_recipes_with_own_recipe(
        self,
        client: AsyncClient,
        override_current_user: User,
        test_recipe: Recipe,
        db_session: AsyncSession,
    ):
        """Should return user's own recipes"""
        response = await client.get(f"{settings.API_V1_STR}/recipes")

        assert response.status_code == 200
        data = response.json()
        assert "results" in data

        recipe_ids = [r["id"] for r in data["results"]]
        assert test_recipe.id in recipe_ids

    @pytest.mark.anyio
    async def test_get_recipes_includes_own_private(
        self,
        client: AsyncClient,
        override_current_user: User,
        db_session: AsyncSession,
        categories: list[RecipeCategories],
        units: list[Unit],
        test_user: User,
    ):
        """Should include user's own private recipes"""
        # Create a private recipe for test_user
        private_recipe = Recipe(
            owner_id=test_user.id,
            is_private=True,
            is_draft=False,
            language="en",
            created_at=datetime.now(UTC),
        )

        revision = RecipeRevision(
            recipe=private_recipe,
            title="My Private Recipe",
            difficulty=1,
            categories=[categories[0]],
            created_at=datetime.now(UTC),
        )

        ingredient_group = IngredientGroup(
            name="Ingredients",
            position=0,
            recipe_revision=revision,
        )
        _add_minimal_ingredient(ingredient_group, units[0].id)

        instruction_group = InstructionGroup(
            name="Steps",
            instructions="Private steps",
            position=0,
            recipe_revision=revision,
        )

        private_recipe.latest_revision = revision
        db_session.add(private_recipe)
        await db_session.flush()

        response = await client.get(f"{settings.API_V1_STR}/recipes")

        assert response.status_code == 200
        data = response.json()
        recipe_ids = [r["id"] for r in data["results"]]
        assert private_recipe.id in recipe_ids

    @pytest.mark.anyio
    async def test_get_recipes_excludes_others_private(
        self,
        client: AsyncClient,
        override_current_user: User,
        private_recipe: Recipe,
    ):
        """Should exclude other users' private recipes"""
        response = await client.get(f"{settings.API_V1_STR}/recipes")

        assert response.status_code == 200
        data = response.json()
        recipe_ids = [r["id"] for r in data["results"]]
        assert private_recipe.id not in recipe_ids

    @pytest.mark.anyio
    async def test_get_recipes_includes_others_public(
        self,
        client: AsyncClient,
        override_current_user: User,
        db_session: AsyncSession,
        other_user: User,
        categories: list[RecipeCategories],
        units: list[Unit],
    ):
        """Should include public recipes from other users"""
        # Create a public recipe for other_user
        public_recipe = Recipe(
            owner_id=other_user.id,
            is_private=False,
            is_draft=False,
            language="en",
            created_at=datetime.now(UTC),
        )

        revision = RecipeRevision(
            recipe=public_recipe,
            title="Other User's Public Recipe",
            difficulty=2,
            categories=[categories[0]],
            created_at=datetime.now(UTC),
        )

        ingredient_group = IngredientGroup(
            name="Ingredients",
            position=0,
            recipe_revision=revision,
        )
        _add_minimal_ingredient(ingredient_group, units[0].id)

        instruction_group = InstructionGroup(
            name="Steps",
            instructions="Public steps",
            position=0,
            recipe_revision=revision,
        )

        public_recipe.latest_revision = revision
        db_session.add(public_recipe)
        await db_session.flush()

        response = await client.get(f"{settings.API_V1_STR}/recipes")

        assert response.status_code == 200
        data = response.json()
        recipe_ids = [r["id"] for r in data["results"]]
        assert public_recipe.id in recipe_ids


class TestCreateRecipe:
    """Integration tests for POST /recipes"""

    @pytest.mark.anyio
    async def test_create_recipe_success(
        self,
        client: AsyncClient,
        override_current_user: User,
        sample_recipe_data: dict,
        db_session: AsyncSession,
    ):
        """Should create a new recipe in the database"""
        response = await client.post(
            f"{settings.API_V1_STR}/recipes", json=sample_recipe_data
        )

        assert response.status_code == 201, response.json()
        data = response.json()

        # Verify response structure
        assert "id" in data
        assert "latest_revision" in data
        assert data["latest_revision"]["title"] == "Chocolate Chip Cookies"
        assert data["is_private"] == False
        assert data["is_draft"] == False
        assert data["language"] == "en"
        assert data["updated_at"]

        # Verify it's actually in the database
        recipe_id = data["id"]
        result = await db_session.execute(select(Recipe).where(Recipe.id == recipe_id))
        recipe = result.scalar_one_or_none()
        assert recipe is not None
        assert recipe.owner_id == override_current_user.id

    @pytest.mark.anyio
    async def test_create_recipe_with_relationships(
        self,
        client: AsyncClient,
        override_current_user: User,
        sample_recipe_data: dict,
        db_session: AsyncSession,
    ):
        """Should create recipe with all relationships in database"""
        response = await client.post(
            f"{settings.API_V1_STR}/recipes", json=sample_recipe_data
        )

        assert response.status_code == 201
        data = response.json()
        recipe_id = data["id"]

        # Verify ingredient groups were created
        result = await db_session.execute(
            select(IngredientGroup)
            .join(IngredientGroup.recipe_revision)
            .join(RecipeRevision.recipe)
            .where(Recipe.id == recipe_id)
        )
        ingredient_groups = result.scalars().all()
        assert len(ingredient_groups) == 2

        # Verify ingredients were created
        result = await db_session.execute(
            select(Ingredient)
            .join(Ingredient.ingredient_group)
            .join(IngredientGroup.recipe_revision)
            .join(RecipeRevision.recipe)
            .where(Recipe.id == recipe_id)
        )
        ingredients = result.scalars().all()
        assert len(ingredients) == 3

    @pytest.mark.anyio
    async def test_create_recipe_invalid_category(
        self,
        client: AsyncClient,
        override_current_user: User,
        sample_recipe_data: dict,
    ):
        """Should fail with invalid category ID"""
        sample_recipe_data["content"]["categories"] = [99999]

        response = await client.post(
            f"{settings.API_V1_STR}/recipes", json=sample_recipe_data
        )

        assert response.status_code == 400
        assert "category" in response.json()["detail"].lower()

    @pytest.mark.anyio
    async def test_create_recipe_invalid_unit(
        self,
        client: AsyncClient,
        override_current_user: User,
        sample_recipe_data: dict,
    ):
        """Should fail with invalid unit ID"""
        sample_recipe_data["content"]["ingredient_groups"][0]["ingredients"][0][
            "unit_id"
        ] = 99999

        response = await client.post(
            f"{settings.API_V1_STR}/recipes", json=sample_recipe_data
        )

        assert response.status_code == 400
        assert "unit" in response.json()["detail"].lower()


class TestUpdateRecipe:
    """Integration tests for PUT /recipes/{recipe_id}"""

    @pytest.mark.anyio
    async def test_update_recipe_success(
        self,
        client: AsyncClient,
        override_current_user: User,
        test_recipe: Recipe,
        sample_recipe_data: dict,
        db_session: AsyncSession,
    ):
        """Should update an existing recipe in database"""
        sample_recipe_data["content"]["title"] = "Updated Recipe Title"

        response = await client.put(
            f"{settings.API_V1_STR}/recipes/{test_recipe.id}", json=sample_recipe_data
        )
        assert response.status_code == 201
        data = response.json()
        old_created_at = data["created_at"]
        old_updated_at = data["updated_at"]
        # do another update to properly test the update_at
        await asyncio.sleep(1)

        response = await client.put(
            f"{settings.API_V1_STR}/recipes/{test_recipe.id}", json=sample_recipe_data
        )

        assert response.status_code == 201
        data = response.json()
        assert data["latest_revision"]["title"] == "Updated Recipe Title"
        assert data["id"] == test_recipe.id

        response = await client.get(f"{settings.API_V1_STR}/recipes/{test_recipe.id}")

        assert response.status_code == 200
        data = response.json()
        assert data["latest_revision"]["title"] == "Updated Recipe Title"
        assert data["id"] == test_recipe.id

        assert data["created_at"] == old_created_at
        assert data["updated_at"] != old_updated_at

        dt_old = datetime.fromisoformat(old_updated_at)
        dt_new = datetime.fromisoformat(data["updated_at"])

        assert (dt_new - dt_old) >= timedelta(seconds=1)

    @pytest.mark.anyio
    async def test_update_creates_new_revision(
        self,
        client: AsyncClient,
        override_current_user: User,
        test_recipe: Recipe,
        sample_recipe_data: dict,
        db_session: AsyncSession,
    ):
        """Should create a new revision, not modify existing"""
        original_revision_id = test_recipe.latest_revision_id
        sample_recipe_data["content"]["title"] = "New Revision"

        response = await client.put(
            f"{settings.API_V1_STR}/recipes/{test_recipe.id}", json=sample_recipe_data
        )

        assert response.status_code == 201

        # Verify both revisions exist in database
        result = await db_session.execute(
            select(RecipeRevision).where(RecipeRevision.recipe_id == test_recipe.id)
        )
        revisions = result.unique().scalars().all()
        assert len(revisions) == 2

    @pytest.mark.anyio
    async def test_update_recipe_not_owner(
        self,
        client: AsyncClient,
        override_current_user: User,
        private_recipe: Recipe,
        sample_recipe_data: dict,
    ):
        """Should fail when updating someone else's recipe"""
        response = await client.put(
            f"{settings.API_V1_STR}/recipes/{private_recipe.id}",
            json=sample_recipe_data,
        )

        assert response.status_code == 404

    @pytest.mark.anyio
    async def test_update_nonexistent_recipe(
        self,
        client: AsyncClient,
        override_current_user: User,
        sample_recipe_data: dict,
    ):
        """Should fail when recipe doesn't exist"""
        response = await client.put(
            f"{settings.API_V1_STR}/recipes/99999", json=sample_recipe_data
        )

        assert response.status_code == 404


class TestGetRecipe:
    """Integration tests for GET /recipes/{recipe_id}"""

    @pytest.mark.anyio
    async def test_get_recipe_with_relationships(
        self,
        client: AsyncClient,
        override_current_user: User,
        test_recipe: Recipe,
    ):
        """Should return recipe with all relationships loaded"""
        response = await client.get(f"{settings.API_V1_STR}/recipes/{test_recipe.id}")

        assert response.status_code == 200
        data = response.json()
        assert "latest_revision" in data
        assert "ingredient_groups" in data["latest_revision"]
        assert "instruction_groups" in data["latest_revision"]
        assert "categories" in data["latest_revision"]
        assert len(data["latest_revision"]["ingredient_groups"]) > 0

    @pytest.mark.anyio
    async def test_get_public_recipe_different_owner(
        self,
        client: AsyncClient,
        override_current_user: User,
        db_session: AsyncSession,
        other_user: User,
        categories: list[RecipeCategories],
        units: list[Unit],
    ):
        """Should access public recipe from another user"""
        public_recipe = Recipe(
            owner_id=other_user.id,
            is_private=False,
            is_draft=False,
            language="en",
            created_at=datetime.now(UTC),
        )

        revision = RecipeRevision(
            recipe=public_recipe,
            title="Other User's Recipe",
            difficulty=2,
            categories=[categories[0]],
            created_at=datetime.now(UTC),
        )

        ingredient_group = IngredientGroup(
            name="Ingredients",
            position=0,
            recipe_revision=revision,
        )
        _add_minimal_ingredient(ingredient_group, units[0].id)

        instruction_group = InstructionGroup(
            name="Steps",
            instructions="Steps",
            position=0,
            recipe_revision=revision,
        )

        public_recipe.latest_revision = revision
        db_session.add(public_recipe)
        await db_session.flush()

        response = await client.get(f"{settings.API_V1_STR}/recipes/{public_recipe.id}")

        assert response.status_code == 200
        data = response.json()
        assert data["id"] == public_recipe.id

    @pytest.mark.anyio
    async def test_get_private_recipe_not_owner(
        self,
        client: AsyncClient,
        override_current_user: User,
        private_recipe: Recipe,
    ):
        """Should fail when accessing private recipe of another user"""
        response = await client.get(
            f"{settings.API_V1_STR}/recipes/{private_recipe.id}"
        )

        assert response.status_code == 404

    @pytest.mark.anyio
    async def test_get_nonexistent_recipe(
        self,
        client: AsyncClient,
        override_current_user: User,
    ):
        """Should return 404 for nonexistent recipe"""
        response = await client.get(f"{settings.API_V1_STR}/recipes/99999")

        assert response.status_code == 404


class TestGetRecipeVersions:
    """Integration tests for GET /recipes/{recipe_id}/versions"""

    @pytest.mark.anyio
    async def test_get_recipe_versions_single(
        self,
        client: AsyncClient,
        override_current_user: User,
        test_recipe: Recipe,
    ):
        """Should return recipe with all versions from database"""
        response = await client.get(
            f"{settings.API_V1_STR}/recipes/{test_recipe.id}/versions"
        )

        assert response.status_code == 200
        data = response.json()
        assert "revisions" in data
        assert len(data["revisions"]) >= 1

    @pytest.mark.anyio
    async def test_get_recipe_versions_multiple(
        self,
        client: AsyncClient,
        override_current_user: User,
        test_recipe: Recipe,
        sample_recipe_data: dict,
        db_session: AsyncSession,
    ):
        """Should return all revisions after multiple updates"""
        # Create first update
        sample_recipe_data["content"]["title"] = "Version 2"
        await client.put(
            f"{settings.API_V1_STR}/recipes/{test_recipe.id}", json=sample_recipe_data
        )

        # Create second update
        sample_recipe_data["content"]["title"] = "Version 3"
        await client.put(
            f"{settings.API_V1_STR}/recipes/{test_recipe.id}", json=sample_recipe_data
        )

        response = await client.get(
            f"{settings.API_V1_STR}/recipes/{test_recipe.id}/versions"
        )

        assert response.status_code == 200
        data = response.json()
        assert len(data["revisions"]) == 3

        # Verify in database
        result = await db_session.execute(
            select(RecipeRevision).where(RecipeRevision.recipe_id == test_recipe.id)
        )
        db_revisions = result.unique().scalars().all()
        assert len(db_revisions) == 3

    @pytest.mark.anyio
    async def test_get_versions_private_recipe_not_owner(
        self,
        client: AsyncClient,
        override_current_user: User,
        private_recipe: Recipe,
    ):
        """Should fail when accessing versions of private recipe"""
        response = await client.get(
            f"{settings.API_V1_STR}/recipes/{private_recipe.id}/versions"
        )

        assert response.status_code == 404


class TestMultiUserScenarios:
    """Integration tests for multi-user interactions"""

    @pytest.mark.anyio
    async def test_different_users_create_recipes(
        self,
        client: AsyncClient,
        test_user: User,
        other_user: User,
        sample_recipe_data: dict,
        db_session: AsyncSession,
    ):
        """Should allow different users to create their own recipes"""

        # Create recipe as test_user
        async def _get_test_user():
            return test_user

        app.dependency_overrides[get_current_user] = _get_test_user

        response1 = await client.post(
            f"{settings.API_V1_STR}/recipes", json=sample_recipe_data
        )
        assert response1.status_code == 201
        recipe1_id = response1.json()["id"]

        # Create recipe as other_user
        async def _get_other_user():
            return other_user

        app.dependency_overrides[get_current_user] = _get_other_user

        sample_recipe_data["content"]["title"] = "Other User's Recipe"
        response2 = await client.post(
            f"{settings.API_V1_STR}/recipes", json=sample_recipe_data
        )
        assert response2.status_code == 201
        recipe2_id = response2.json()["id"]

        # Verify both recipes exist with correct owners
        result1 = await db_session.execute(
            select(Recipe).where(Recipe.id == recipe1_id)
        )
        recipe1 = result1.scalar_one()
        assert recipe1.owner_id == test_user.id

        result2 = await db_session.execute(
            select(Recipe).where(Recipe.id == recipe2_id)
        )
        recipe2 = result2.scalar_one()
        assert recipe2.owner_id == other_user.id


class TestGetRecipesQueryParams:
    """Test various query params for sorting/filtering"""

    @pytest.mark.anyio
    async def test_query(
        self,
        client: AsyncClient,
        override_current_user: User,
        sample_recipe_data: dict,
        db_session: AsyncSession,
    ):
        """Should create a new recipe in the database"""
        sample_recipe_data["content"]["title"] = "111"
        response = await client.post(
            f"{settings.API_V1_STR}/recipes", json=sample_recipe_data
        )

        assert response.status_code == 201
        data = response.json()
        ts1_upat = data["updated_at"]
        ts1_crat = data["created_at"]

        await asyncio.sleep(1)
        # create a second recipe
        sample_recipe_data["content"]["title"] = "222"
        response = await client.post(
            f"{settings.API_V1_STR}/recipes", json=sample_recipe_data
        )
        assert response.status_code == 201
        data = response.json()
        ts2_upat = data["updated_at"]
        ts2_crat = data["created_at"]

        await asyncio.sleep(1)
        # third recipe
        sample_recipe_data["content"]["title"] = "333"
        response = await client.post(
            f"{settings.API_V1_STR}/recipes", json=sample_recipe_data
        )
        assert response.status_code == 201
        data = response.json()
        ts3_upat = data["updated_at"]
        ts3_crat = data["created_at"]

        response = await client.get(
            f"{settings.API_V1_STR}/recipes?sort_by=updated_at&order=asc",
        )

        assert response.status_code == 200
        data = response.json()["results"]
        assert data[0]["latest_revision"]["title"] == "111"
        assert data[1]["latest_revision"]["title"] == "222"
        assert data[2]["latest_revision"]["title"] == "333"

        response = await client.get(
            f"{settings.API_V1_STR}/recipes",
            params={"sort_by": "updated_at", "order": "adsfsdfsdsc"},
        )
        assert response.status_code == 422

        response = await client.get(
            f"{settings.API_V1_STR}/recipes",
            params={"sort_by": "updated_at", "order": "desc"},
        )

        assert response.status_code == 200
        data = response.json()["results"]
        assert data[2]["latest_revision"]["title"] == "111"
        assert data[1]["latest_revision"]["title"] == "222"
        assert data[0]["latest_revision"]["title"] == "333"

        # test date_from
        response = await client.get(
            f"{settings.API_V1_STR}/recipes",
            params={"date_from": ts2_crat, "date_column": "updated_at"},
        )

        assert response.status_code == 200
        data = response.json()["results"]
        assert len(data) == 2
        assert data[1]["latest_revision"]["title"] == "222"
        assert data[0]["latest_revision"]["title"] == "333"

        response = await client.get(
            f"{settings.API_V1_STR}/recipes",
            params={
                "date_from": ts2_crat,
                "date_column": "updated_at",
                "sort_by": "updated_at",
                "order": "asc",
            },
        )

        assert response.status_code == 200
        data = response.json()["results"]
        assert len(data) == 2
        assert data[0]["latest_revision"]["title"] == "222"
        assert data[1]["latest_revision"]["title"] == "333"

        response = await client.get(
            f"{settings.API_V1_STR}/recipes",
            params={
                "date_from": str(datetime.now(UTC)),
                "date_column": "updated_at",
                "sort_by": "updated_at",
                "order": "asc",
            },
        )

        assert response.status_code == 200
        data = response.json()["results"]
        assert len(data) == 0
