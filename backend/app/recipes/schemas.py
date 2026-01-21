from enum import StrEnum
from typing import Annotated, List
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator
from pydantic_core.core_schema import ValidationInfo

from app.auth.models import USER_ID_T
from app.recipes.constants import LANGUAGE_CODE, BaseUnit, UnitSystem



ALLOWED_LANGUAGES = list(LANGUAGE_CODE.keys())
MIN_STRING_LENGTH = 2
MAX_NAME_LENGTH = 512
MAX_DESCRIPTION_LENGTH = 1024
MAX_INSTRUCTIONS_LENGTH = 10000
MAX_TIME_MINUTES = 9999
MIN_SERVINGS = 1
MAX_SERVINGS = 10000
MIN_DIFFICULTY = 1
MAX_DIFFICULTY = 5


class FoodCandidateRead(BaseModel):
    name: str
    description: str | None
    language: str
    wiki_id: str | None = None
    openfooodfacts_id: str | None = None
    usda_ndb_id: str | None = None

    @field_validator("name")
    @classmethod
    def validate_name(cls, v: str) -> str:
        v = v.strip()
        if len(v) < MIN_STRING_LENGTH:
            raise ValueError(f"name must be at least {MIN_STRING_LENGTH} characters")
        if len(v) > MAX_NAME_LENGTH:
            raise ValueError(f"name must not exceed {MAX_NAME_LENGTH} characters")
        return v

    @field_validator("description")
    @classmethod
    def validate_description(cls, v: str | None) -> str | None:
        if v is not None:
            v = v.strip()
            if len(v) == 0:
                return None
            if len(v) > MAX_DESCRIPTION_LENGTH:
                raise ValueError(
                    f"description must not exceed {MAX_DESCRIPTION_LENGTH} characters"
                )
        return v

    @field_validator("language")
    @classmethod
    def validate_language(cls, v: str) -> str:
        if v not in ALLOWED_LANGUAGES:
            raise ValueError(f"language must be one of {ALLOWED_LANGUAGES}, got '{v}'")
        return v


class UnitRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    base_unit: str | None
    unit_system: str
    conversion_factor: float | None

    @field_validator("name")
    @classmethod
    def validate_name(cls, v: str) -> str:
        v = v.strip()
        if len(v) < MIN_STRING_LENGTH:
            raise ValueError(f"name must be at least {MIN_STRING_LENGTH} characters")
        if len(v) > MAX_NAME_LENGTH:
            raise ValueError(f"name must not exceed {MAX_NAME_LENGTH} characters")
        return v

    @field_validator("base_unit")
    @classmethod
    def validate_base_unit(cls, v: str | None) -> str | None:
        if v is not None and v not in [e.value for e in BaseUnit]:
            raise ValueError(f"base_unit must be a valid BaseUnit enum value")
        return v

    @field_validator("unit_system")
    @classmethod
    def validate_unit_system(cls, v: str) -> str:
        if v not in [e.value for e in UnitSystem]:
            raise ValueError(f"unit_system must be a valid UnitSystem enum value")
        return v


class IngredientBase(BaseModel):
    food: str | None
    amount_min: float | None = None
    amount_max: float | None = None
    comment: Annotated[
        str | None,
        Field(
            description="Use for additionial instructions like finely-chopped, or further specificiation, like large or two small"
        ),
    ]

    @field_validator("food")
    @classmethod
    def validate_food(cls, v: str | None) -> str | None:
        if v is None:
            return v
        v = v.strip()
        if len(v) > MAX_NAME_LENGTH:
            raise ValueError(f"food must not exceed {MAX_NAME_LENGTH} characters")
        return v

    @field_validator("comment")
    @classmethod
    def validate_comment(cls, v: str | None) -> str | None:
        if v is None:
            return v

        v = v.strip()
        if len(v) > 512:
            raise ValueError(f"food must not exceed {512} characters")
        return v

    @field_validator("amount_min")
    @classmethod
    def validate_amount_min(cls, v: float | None) -> float | None:
        if v is None:
            return None
        if v <= 0:
            raise ValueError("amount_min must be greater than 0")
        return round(v, 2)

    @field_validator("amount_max")
    @classmethod
    def validate_amount_max(cls, v: float | None) -> float | None:
        if v is not None:
            if v <= 0:
                raise ValueError("amount_max must be greater than 0")
            return round(v, 2)
        return v

    @model_validator(mode="after")
    def validate_amount_range(self) -> "IngredientBase":
        if self.amount_max is not None:
            if self.amount_min is None:
                raise ValueError("amount_max requires amount_min to be set")
            if self.amount_max <= self.amount_min:
                raise ValueError("amount_max must be greater than amount_min")
        return self


class IngredientRead(IngredientBase):
    model_config = ConfigDict(from_attributes=True)
    unit: UnitRead | None


class IngredientWrite(IngredientBase):
    unit_id: int | None


class IngredientGroupBase(BaseModel):
    name: str | None

    @field_validator("name")
    @classmethod
    def validate_name(cls, v: str | None) -> str | None:
        if v is None:
            return None
        v = v.strip()
        if len(v) > MAX_NAME_LENGTH:
            raise ValueError(f"name must not exceed {MAX_NAME_LENGTH} characters")
        return v


class IngredientGroupRead(IngredientGroupBase):
    model_config = ConfigDict(from_attributes=True)
    ingredients: list[IngredientRead]

    @field_validator("ingredients")
    @classmethod
    def validate_ingredients_not_empty(cls, v: list) -> list:
        if len(v) == 0:
            raise ValueError("ingredients list must contain at least one ingredient")
        return v


class IngredientGroupWrite(IngredientGroupBase):
    ingredients: list[IngredientWrite]

    @field_validator("ingredients")
    @classmethod
    def validate_ingredients_not_empty(cls, v: list) -> list:
        if len(v) == 0:
            raise ValueError("ingredients list must contain at least one ingredient")
        return v


class InstructionGroupIO(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    name: str | None
    instructions: str | None

    @field_validator("name")
    @classmethod
    def validate_name(cls, v: str | None) -> str | None:
        if v is None:
            return v

        v = v.strip()
        if len(v) > MAX_NAME_LENGTH:
            raise ValueError(f"name must not exceed {MAX_NAME_LENGTH} characters")
        return v

    @field_validator("instructions")
    @classmethod
    def validate_instructions(cls, v: str | None) -> str | None:
        if v is None:
            return v
        v = v.strip()
        if len(v) > MAX_INSTRUCTIONS_LENGTH:
            raise ValueError(
                f"instructions must not exceed {MAX_INSTRUCTIONS_LENGTH} characters"
            )
        return v


class RecipeCategoryRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    name: str


class RecipeRevisionBase(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    title: str | None
    subtitle: str | None
    owner_comment: str | None

    difficulty: int | None
    servings: int | None
    prep_time: int | None
    cook_time: int | None

    source_name: str | None
    source_page: str | None
    source_url: str | None

    instruction_groups: List[InstructionGroupIO]

    @field_validator("title")
    @classmethod
    def validate_title(cls, v: str | None) -> str | None:
        if v is None:
            return v
        v = v.strip()
        if len(v) > MAX_NAME_LENGTH:
            raise ValueError(f"title must not exceed {MAX_NAME_LENGTH} characters")
        return v

    @field_validator("subtitle")
    @classmethod
    def validate_subtitle(cls, v: str | None) -> str | None:
        if v is not None:
            v = v.strip()
            if len(v) == 0:
                return None
            if len(v) > 1024:
                raise ValueError(
                    f"subtitle must not exceed {MAX_NAME_LENGTH} characters"
                )
        return v

    @field_validator("owner_comment")
    @classmethod
    def validate_owner_comment(cls, v: str | None) -> str | None:
        if v is not None:
            v = v.strip()
            if len(v) == 0:
                return None
            if len(v) > MAX_DESCRIPTION_LENGTH:
                raise ValueError(
                    f"owner_comment must not exceed {MAX_DESCRIPTION_LENGTH} characters"
                )
        return v

    @field_validator("difficulty")
    @classmethod
    def validate_difficulty(cls, v: int | None) -> int | None:
        if v is not None and (v < MIN_DIFFICULTY or v > MAX_DIFFICULTY):
            raise ValueError(
                f"difficulty must be between {MIN_DIFFICULTY} and {MAX_DIFFICULTY}"
            )
        return v

    @field_validator("servings")
    @classmethod
    def validate_servings(cls, v: int | None) -> int | None:
        if v is not None:
            if v < MIN_SERVINGS or v > MAX_SERVINGS:
                raise ValueError(
                    f"servings must be between {MIN_SERVINGS} and {MAX_SERVINGS}"
                )
        return v

    # @field_validator("prep_time", "cook_time")
    # @classmethod
    # def validate_time(cls, v: int | None) -> int | None:
    #     if v is not None:
    #         if v < 0 or v > MAX_TIME_MINUTES:
    #             raise ValueError(
    #                 f"time must be between 1 and {MAX_TIME_MINUTES} minutes"
    #             )
    #     return v

    @field_validator("source_name", "source_page")
    @classmethod
    def validate_source_text(cls, v: str | None) -> str | None:
        if v is not None:
            v = v.strip()
            if len(v) == 0:
                return None
            if len(v) > MAX_NAME_LENGTH:
                raise ValueError(
                    f"source field must not exceed {MAX_NAME_LENGTH} characters"
                )
        return v

    @field_validator("source_url")
    @classmethod
    def validate_source_url(cls, v: str | None) -> str | None:
        if v is not None:
            v = v.strip()
            if len(v) == 0:
                return None
            if len(v) > MAX_NAME_LENGTH:
                raise ValueError(
                    f"source_url must not exceed {MAX_NAME_LENGTH} characters"
                )
            # Basic URL validation
            if not (v.startswith("http://") or v.startswith("https://")):
                raise ValueError("source_url must start with http:// or https://")
        return v

    @field_validator("instruction_groups")
    @classmethod
    def validate_instruction_groups_not_empty(cls, v: list) -> list:
        if len(v) == 0:
            raise ValueError(
                "instruction_groups list must contain at least one instruction group"
            )
        return v


class RecipeRevisionCreateUpdate(RecipeRevisionBase):
    ingredient_groups: List[IngredientGroupWrite]
    categories: set[int]

    @field_validator("ingredient_groups")
    @classmethod
    def validate_ingredient_groups_not_empty(cls, v: list) -> list:
        if len(v) == 0:
            raise ValueError(
                "ingredient_groups list must contain at least one ingredient group"
            )
        return v


class RecipeRevisionRead(RecipeRevisionBase):
    categories: list[RecipeCategoryRead]
    ingredient_groups: List[IngredientGroupRead]
    created_at: datetime


class RecipeBase(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    is_private: bool
    is_draft: bool
    language: str

    @field_validator("language")
    @classmethod
    def validate_language(cls, v: str) -> str:
        if v not in ALLOWED_LANGUAGES:
            raise ValueError(f"language must be one of {ALLOWED_LANGUAGES}, got '{v}'")
        return v


class RecipeCreateUpdate(RecipeBase):
    content: RecipeRevisionCreateUpdate


class RecipeReadHeader(RecipeBase):
    model_config = ConfigDict(from_attributes=True)
    id: int
    owner_id: USER_ID_T
    created_at: datetime
    updated_at: datetime
    is_favorited: bool = False


class RecipeRead(RecipeReadHeader):
    model_config = ConfigDict(from_attributes=True)
    latest_revision: RecipeRevisionRead


class RecipeReadHistory(RecipeReadHeader):
    model_config = ConfigDict(from_attributes=True)
    revisions: list[RecipeRevisionRead]


class RecipeListView(RecipeReadHeader):
    title: str | None
    subtitle: str | None
    owner_comment: str | None
    prep_time: int | None
    cook_time: int | None
    servings: int | None
    difficulty: int | None
    categories: list[str]
