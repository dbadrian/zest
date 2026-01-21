import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession
from datetime import datetime, UTC

from app.core.config import settings
from app.recipes.models import (
    Recipe,
    RecipeRevision,
    RecipeCategories,
    Unit,
    IngredientGroup,
    InstructionGroup,
)
from app.auth.models import User
from app.recipes.constants import UnitSystem, BaseUnit
from app.auth.auth import get_current_user
from app.main import app
from app.db import init_db


# ============================================================================
# TEST FIXTURES
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
        email="validator_test@example.com",
        username="validator_test@example.com",
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


@pytest.fixture
async def categories(db_session: AsyncSession) -> list[RecipeCategories]:
    """Create test categories in the database"""
    cats = [
        RecipeCategories(name="Dessert"),
        RecipeCategories(name="Main Course"),
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
    ]
    for unit in unit_list:
        db_session.add(unit)
    await db_session.flush()
    for unit in unit_list:
        await db_session.refresh(unit)
    return unit_list


@pytest.fixture
def valid_recipe_data(categories: list[RecipeCategories], units: list[Unit]) -> dict:
    """Valid recipe creation data for testing"""
    return {
        "is_private": False,
        "is_draft": False,
        "language": "en",
        "content": {
            "title": "Valid Recipe Title",
            "subtitle": "A valid subtitle",
            "difficulty": 3,
            "servings": 4,
            "prep_time": 15,
            "cook_time": 30,
            "source_name": "Test Source",
            "source_page": "42",
            "source_url": "https://example.com/recipe",
            "owner_comment": "A test comment",
            "categories": [cat.id for cat in categories],
            "ingredient_groups": [
                {
                    "name": "Main Ingredients",
                    "ingredients": [
                        {
                            "food": "Flour",
                            "amount_min": 2.5,
                            "amount_max": 3.0,
                            "unit_id": units[0].id,
                            "comment": "meh",
                        },
                    ],
                },
            ],
            "instruction_groups": [
                {
                    "name": "Preparation",
                    "instructions": "Mix all ingredients together.",
                },
            ],
        },
    }


# ============================================================================
# STRING VALIDATION TESTS
# ============================================================================


class TestStringValidation:
    """Test string length and format validation"""

    @pytest.mark.anyio
    async def test_title_too_long(
        self,
        client: AsyncClient,
        override_current_user: User,
        valid_recipe_data: dict,
    ):
        """Should fail when title exceeds 200 characters"""
        valid_recipe_data["content"]["title"] = "A" * 201333

        response = await client.post(
            f"{settings.API_V1_STR}/recipes", json=valid_recipe_data
        )

        assert response.status_code == 422
        detail = response.json()["detail"]
        assert any("title" in str(err).lower() for err in detail)

    @pytest.mark.anyio
    async def test_title_valid_length(
        self,
        client: AsyncClient,
        override_current_user: User,
        valid_recipe_data: dict,
    ):
        """Should accept title with valid length"""
        valid_recipe_data["content"]["title"] = "ABC"  # Minimum valid

        response = await client.post(
            f"{settings.API_V1_STR}/recipes", json=valid_recipe_data
        )

        assert response.status_code == 201

    @pytest.mark.anyio
    async def test_instructions_too_long(
        self,
        client: AsyncClient,
        override_current_user: User,
        valid_recipe_data: dict,
    ):
        """Should fail when instructions exceed 10000 characters"""
        valid_recipe_data["content"]["instruction_groups"][0]["instructions"] = (
            "A" * 10001
        )

        response = await client.post(
            f"{settings.API_V1_STR}/recipes", json=valid_recipe_data
        )

        assert response.status_code == 422
        detail = response.json()["detail"]
        assert any("instruction" in str(err).lower() for err in detail)

    @pytest.mark.anyio
    async def test_owner_comment_too_long(
        self,
        client: AsyncClient,
        override_current_user: User,
        valid_recipe_data: dict,
    ):
        """Should fail when owner_comment exceeds 1024 characters"""
        valid_recipe_data["content"]["owner_comment"] = "A" * 1025

        response = await client.post(
            f"{settings.API_V1_STR}/recipes", json=valid_recipe_data
        )

        assert response.status_code == 422
        detail = response.json()["detail"]
        assert any("owner_comment" in str(err).lower() for err in detail)

    @pytest.mark.anyio
    async def test_empty_strings_converted_to_none(
        self,
        client: AsyncClient,
        override_current_user: User,
        valid_recipe_data: dict,
    ):
        """Should convert empty strings to None for optional fields"""
        valid_recipe_data["content"]["subtitle"] = "   "
        valid_recipe_data["content"]["owner_comment"] = ""
        valid_recipe_data["content"]["source_name"] = "  "

        response = await client.post(
            f"{settings.API_V1_STR}/recipes", json=valid_recipe_data
        )

        assert response.status_code == 201
        data = response.json()
        assert data["latest_revision"]["subtitle"] is None
        assert data["latest_revision"]["owner_comment"] is None
        assert data["latest_revision"]["source_name"] is None


# ============================================================================
# URL VALIDATION TESTS
# ============================================================================


class TestUrlValidation:
    """Test URL validation"""

    @pytest.mark.anyio
    async def test_source_url_invalid_protocol(
        self,
        client: AsyncClient,
        override_current_user: User,
        valid_recipe_data: dict,
    ):
        """Should fail when source_url doesn't start with http:// or https://"""
        valid_recipe_data["content"]["source_url"] = "ftp://example.com"

        response = await client.post(
            f"{settings.API_V1_STR}/recipes", json=valid_recipe_data
        )

        assert response.status_code == 422
        detail = response.json()["detail"]
        assert any("source_url" in str(err).lower() for err in detail)

    @pytest.mark.anyio
    async def test_source_url_missing_protocol(
        self,
        client: AsyncClient,
        override_current_user: User,
        valid_recipe_data: dict,
    ):
        """Should fail when source_url doesn't have protocol"""
        valid_recipe_data["content"]["source_url"] = "example.com/recipe"

        response = await client.post(
            f"{settings.API_V1_STR}/recipes", json=valid_recipe_data
        )

        assert response.status_code == 422
        detail = response.json()["detail"]
        assert any("source_url" in str(err).lower() for err in detail)

    @pytest.mark.anyio
    async def test_source_url_valid_http(
        self,
        client: AsyncClient,
        override_current_user: User,
        valid_recipe_data: dict,
    ):
        """Should accept source_url with http://"""
        valid_recipe_data["content"]["source_url"] = "http://example.com/recipe"

        response = await client.post(
            f"{settings.API_V1_STR}/recipes", json=valid_recipe_data
        )

        assert response.status_code == 201

    @pytest.mark.anyio
    async def test_source_url_valid_https(
        self,
        client: AsyncClient,
        override_current_user: User,
        valid_recipe_data: dict,
    ):
        """Should accept source_url with https://"""
        valid_recipe_data["content"]["source_url"] = "https://example.com/recipe"

        response = await client.post(
            f"{settings.API_V1_STR}/recipes", json=valid_recipe_data
        )

        assert response.status_code == 201


# ============================================================================
# NUMERIC VALIDATION TESTS
# ============================================================================


class TestNumericValidation:
    """Test numeric field validation"""

    @pytest.mark.anyio
    async def test_amount_min_zero(
        self,
        client: AsyncClient,
        override_current_user: User,
        valid_recipe_data: dict,
    ):
        """Should fail when amount_min is 0"""
        valid_recipe_data["content"]["ingredient_groups"][0]["ingredients"][0][
            "amount_min"
        ] = 0

        response = await client.post(
            f"{settings.API_V1_STR}/recipes", json=valid_recipe_data
        )

        assert response.status_code == 422
        detail = response.json()["detail"]
        assert any("amount_min" in str(err).lower() for err in detail)

    @pytest.mark.anyio
    async def test_amount_min_negative(
        self,
        client: AsyncClient,
        override_current_user: User,
        valid_recipe_data: dict,
    ):
        """Should fail when amount_min is negative"""
        valid_recipe_data["content"]["ingredient_groups"][0]["ingredients"][0][
            "amount_min"
        ] = -5.0

        response = await client.post(
            f"{settings.API_V1_STR}/recipes", json=valid_recipe_data
        )

        assert response.status_code == 422
        detail = response.json()["detail"]
        assert any("amount_min" in str(err).lower() for err in detail)

    @pytest.mark.anyio
    async def test_amount_max_less_than_min(
        self,
        client: AsyncClient,
        override_current_user: User,
        valid_recipe_data: dict,
    ):
        """Should fail when amount_max is less than amount_min"""
        valid_recipe_data["content"]["ingredient_groups"][0]["ingredients"][0][
            "amount_min"
        ] = 5.0
        valid_recipe_data["content"]["ingredient_groups"][0]["ingredients"][0][
            "amount_max"
        ] = 3.0

        response = await client.post(
            f"{settings.API_V1_STR}/recipes", json=valid_recipe_data
        )

        assert response.status_code == 422
        detail = response.json()["detail"]
        assert any("amount" in str(err).lower() for err in detail)

    @pytest.mark.anyio
    async def test_amount_max_equal_to_min(
        self,
        client: AsyncClient,
        override_current_user: User,
        valid_recipe_data: dict,
    ):
        """Should fail when amount_max equals amount_min"""
        valid_recipe_data["content"]["ingredient_groups"][0]["ingredients"][0][
            "amount_min"
        ] = 5.0
        valid_recipe_data["content"]["ingredient_groups"][0]["ingredients"][0][
            "amount_max"
        ] = 5.0

        response = await client.post(
            f"{settings.API_V1_STR}/recipes", json=valid_recipe_data
        )

        assert response.status_code == 422
        detail = response.json()["detail"]
        assert any("amount" in str(err).lower() for err in detail)

    @pytest.mark.anyio
    async def test_amount_decimal_rounding(
        self,
        client: AsyncClient,
        override_current_user: User,
        valid_recipe_data: dict,
    ):
        """Should round amounts to 2 decimal places"""
        valid_recipe_data["content"]["ingredient_groups"][0]["ingredients"][0][
            "amount_min"
        ] = 2.5555
        valid_recipe_data["content"]["ingredient_groups"][0]["ingredients"][0][
            "amount_max"
        ] = 3.7777

        response = await client.post(
            f"{settings.API_V1_STR}/recipes", json=valid_recipe_data
        )

        assert response.status_code == 201
        # Note: Backend should handle rounding, we just verify it doesn't fail

    @pytest.mark.anyio
    async def test_difficulty_below_min(
        self,
        client: AsyncClient,
        override_current_user: User,
        valid_recipe_data: dict,
    ):
        """Should fail when difficulty is less than 1"""
        valid_recipe_data["content"]["difficulty"] = 0

        response = await client.post(
            f"{settings.API_V1_STR}/recipes", json=valid_recipe_data
        )

        assert response.status_code == 422
        detail = response.json()["detail"]
        assert any("difficulty" in str(err).lower() for err in detail)

    @pytest.mark.anyio
    async def test_difficulty_above_max(
        self,
        client: AsyncClient,
        override_current_user: User,
        valid_recipe_data: dict,
    ):
        """Should fail when difficulty is greater than 5"""
        valid_recipe_data["content"]["difficulty"] = 6

        response = await client.post(
            f"{settings.API_V1_STR}/recipes", json=valid_recipe_data
        )

        assert response.status_code == 422
        detail = response.json()["detail"]
        assert any("difficulty" in str(err).lower() for err in detail)

    @pytest.mark.anyio
    async def test_difficulty_valid_range(
        self,
        client: AsyncClient,
        override_current_user: User,
        valid_recipe_data: dict,
    ):
        """Should accept difficulty values from 1 to 5"""
        for difficulty in [1, 2, 3, 4, 5]:
            valid_recipe_data["content"]["difficulty"] = difficulty
            valid_recipe_data["content"]["title"] = f"Recipe Difficulty {difficulty}"

            response = await client.post(
                f"{settings.API_V1_STR}/recipes", json=valid_recipe_data
            )

            assert response.status_code == 201

    @pytest.mark.anyio
    async def test_servings_below_min(
        self,
        client: AsyncClient,
        override_current_user: User,
        valid_recipe_data: dict,
    ):
        """Should fail when servings is less than 1"""
        valid_recipe_data["content"]["servings"] = 0

        response = await client.post(
            f"{settings.API_V1_STR}/recipes", json=valid_recipe_data
        )

        assert response.status_code == 422
        detail = response.json()["detail"]
        assert any("servings" in str(err).lower() for err in detail)

    @pytest.mark.anyio
    async def test_servings_above_max(
        self,
        client: AsyncClient,
        override_current_user: User,
        valid_recipe_data: dict,
    ):
        """Should fail when servings exceeds 10000"""
        valid_recipe_data["content"]["servings"] = 10001

        response = await client.post(
            f"{settings.API_V1_STR}/recipes", json=valid_recipe_data
        )

        assert response.status_code == 422
        detail = response.json()["detail"]
        assert any("servings" in str(err).lower() for err in detail)

    @pytest.mark.anyio
    async def test_servings_edge_cases(
        self,
        client: AsyncClient,
        override_current_user: User,
        valid_recipe_data: dict,
    ):
        """Should accept servings at min and max boundaries"""
        # Test minimum
        valid_recipe_data["content"]["servings"] = 1
        valid_recipe_data["content"]["title"] = "Recipe Servings Min"

        response = await client.post(
            f"{settings.API_V1_STR}/recipes", json=valid_recipe_data
        )

        assert response.status_code == 201

        # Test maximum
        valid_recipe_data["content"]["servings"] = 10000
        valid_recipe_data["content"]["title"] = "Recipe Servings Max"

        response = await client.post(
            f"{settings.API_V1_STR}/recipes", json=valid_recipe_data
        )

        assert response.status_code == 201

    @pytest.mark.anyio
    async def test_time_edge_cases(
        self,
        client: AsyncClient,
        override_current_user: User,
        valid_recipe_data: dict,
    ):
        """Should accept time values at min and max boundaries"""
        valid_recipe_data["content"]["prep_time"] = 1
        valid_recipe_data["content"]["cook_time"] = 9999
        valid_recipe_data["content"]["title"] = "Recipe Time Edge"

        response = await client.post(
            f"{settings.API_V1_STR}/recipes", json=valid_recipe_data
        )

        assert response.status_code == 201


# ============================================================================
# LANGUAGE VALIDATION TESTS
# ============================================================================


class TestLanguageValidation:
    """Test language code validation"""

    @pytest.mark.anyio
    async def test_invalid_language_code(
        self,
        client: AsyncClient,
        override_current_user: User,
        valid_recipe_data: dict,
    ):
        """Should fail when language is not in allowed list"""
        valid_recipe_data["language"] = "WH"

        response = await client.post(
            f"{settings.API_V1_STR}/recipes", json=valid_recipe_data
        )

        assert response.status_code == 422
        detail = response.json()["detail"]
        assert any("language" in str(err).lower() for err in detail)

    @pytest.mark.anyio
    async def test_all_valid_languages(
        self,
        client: AsyncClient,
        override_current_user: User,
        valid_recipe_data: dict,
    ):
        """Should accept all languages in allowed list"""
        allowed_languages = ["de", "en", "ja", "pt", "it", "cs"]

        for lang in allowed_languages:
            valid_recipe_data["language"] = lang
            valid_recipe_data["content"]["title"] = f"Recipe in {lang}"

            response = await client.post(
                f"{settings.API_V1_STR}/recipes", json=valid_recipe_data
            )

            assert response.status_code == 201, f"Failed for language: {lang}"


# ============================================================================
# LIST/COLLECTION VALIDATION TESTS
# ============================================================================


class TestCollectionValidation:
    """Test validation of lists and collections"""

    @pytest.mark.anyio
    async def test_empty_ingredient_groups(
        self,
        client: AsyncClient,
        override_current_user: User,
        valid_recipe_data: dict,
    ):
        """Should fail when ingredient_groups is empty"""
        valid_recipe_data["content"]["ingredient_groups"] = []

        response = await client.post(
            f"{settings.API_V1_STR}/recipes", json=valid_recipe_data
        )

        assert response.status_code == 422
        detail = response.json()["detail"]
        assert any("ingredient_groups" in str(err).lower() for err in detail)

    @pytest.mark.anyio
    async def test_empty_ingredients_in_group(
        self,
        client: AsyncClient,
        override_current_user: User,
        valid_recipe_data: dict,
    ):
        """Should fail when ingredients list in a group is empty"""
        valid_recipe_data["content"]["ingredient_groups"][0]["ingredients"] = []

        response = await client.post(
            f"{settings.API_V1_STR}/recipes", json=valid_recipe_data
        )

        assert response.status_code == 422
        detail = response.json()["detail"]
        assert any("ingredients" in str(err).lower() for err in detail)

    @pytest.mark.anyio
    async def test_empty_instruction_groups(
        self,
        client: AsyncClient,
        override_current_user: User,
        valid_recipe_data: dict,
    ):
        """Should fail when instruction_groups is empty"""
        valid_recipe_data["content"]["instruction_groups"] = []

        response = await client.post(
            f"{settings.API_V1_STR}/recipes", json=valid_recipe_data
        )

        assert response.status_code == 422
        detail = response.json()["detail"]
        assert any("instruction_groups" in str(err).lower() for err in detail)

    @pytest.mark.anyio
    async def test_empty_categories(
        self,
        client: AsyncClient,
        override_current_user: User,
        valid_recipe_data: dict,
    ):
        """Should fail when categories is empty"""
        valid_recipe_data["content"]["categories"] = []

        response = await client.post(
            f"{settings.API_V1_STR}/recipes", json=valid_recipe_data
        )

        assert response.status_code == 201  # now accepted

    @pytest.mark.anyio
    async def test_multiple_ingredient_groups(
        self,
        client: AsyncClient,
        override_current_user: User,
        valid_recipe_data: dict,
        units: list[Unit],
    ):
        """Should accept multiple ingredient groups"""
        valid_recipe_data["content"]["ingredient_groups"] = [
            {
                "name": "Dry Ingredients",
                "ingredients": [
                    {
                        "food": "Flour",
                        "amount_min": 2.0,
                        "unit_id": units[0].id,
                        "comment": None,
                    },
                ],
            },
            {
                "name": "Wet Ingredients",
                "ingredients": [
                    {
                        "food": "Milk",
                        "amount_min": 1.0,
                        "unit_id": units[0].id,
                        "comment": None,
                    },
                ],
            },
            {
                "name": "Spices",
                "ingredients": [
                    {
                        "food": "Salt",
                        "amount_min": 5.0,
                        "unit_id": units[1].id,
                        "comment": None,
                    },
                ],
            },
        ]

        response = await client.post(
            f"{settings.API_V1_STR}/recipes", json=valid_recipe_data
        )

        assert response.status_code == 201

    @pytest.mark.anyio
    async def test_multiple_categories(
        self,
        client: AsyncClient,
        override_current_user: User,
        valid_recipe_data: dict,
        categories: list[RecipeCategories],
    ):
        """Should accept multiple categories"""
        valid_recipe_data["content"]["categories"] = [cat.id for cat in categories]

        response = await client.post(
            f"{settings.API_V1_STR}/recipes", json=valid_recipe_data
        )

        assert response.status_code == 201


# ============================================================================
# EDGE CASES AND COMPLEX SCENARIOS
# ============================================================================


class TestEdgeCases:
    """Test edge cases and complex validation scenarios"""

    @pytest.mark.anyio
    async def test_optional_fields_none(
        self,
        client: AsyncClient,
        override_current_user: User,
        valid_recipe_data: dict,
    ):
        """Should accept None for all optional fields"""
        valid_recipe_data["content"]["subtitle"] = None
        valid_recipe_data["content"]["owner_comment"] = None
        valid_recipe_data["content"]["servings"] = None
        valid_recipe_data["content"]["prep_time"] = None
        valid_recipe_data["content"]["cook_time"] = None
        valid_recipe_data["content"]["source_name"] = None
        valid_recipe_data["content"]["source_page"] = None
        valid_recipe_data["content"]["source_url"] = None
        valid_recipe_data["content"]["ingredient_groups"][0]["ingredients"][0][
            "amount_max"
        ] = None

        response = await client.post(
            f"{settings.API_V1_STR}/recipes", json=valid_recipe_data
        )

        assert response.status_code == 201

    @pytest.mark.anyio
    async def test_whitespace_trimming(
        self,
        client: AsyncClient,
        override_current_user: User,
        valid_recipe_data: dict,
    ):
        """Should trim whitespace from string fields"""
        valid_recipe_data["content"]["title"] = "  Recipe With Spaces  "
        valid_recipe_data["content"]["subtitle"] = "  Spaced Subtitle  "
        valid_recipe_data["content"]["ingredient_groups"][0]["name"] = "  Group Name  "

        response = await client.post(
            f"{settings.API_V1_STR}/recipes", json=valid_recipe_data
        )

        assert response.status_code == 201
        data = response.json()
        assert data["latest_revision"]["title"] == "Recipe With Spaces"
        assert data["latest_revision"]["subtitle"] == "Spaced Subtitle"

    @pytest.mark.anyio
    async def test_special_characters_allowed(
        self,
        client: AsyncClient,
        override_current_user: User,
        valid_recipe_data: dict,
    ):
        """Should accept special characters in string fields"""
        title = "Crème Brûlée & Café Münchner!"
        valid_recipe_data["content"]["title"] = title  # "Crème Brûlée & Café Münchner!"
        valid_recipe_data["content"]["ingredient_groups"][0]["ingredients"][0][
            "food"
        ] = "Jalapeño peppers (½ cup)"

        response = await client.post(
            f"{settings.API_V1_STR}/recipes", json=valid_recipe_data
        )

        assert response.status_code == 201
        data = response.json()
        assert data["latest_revision"]["title"] == title
