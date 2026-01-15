from enum import Enum
import re
from datetime import datetime, timedelta, UTC
from uuid import UUID, uuid7

from pydantic_core.core_schema import nullable_schema
from sqlalchemy import (
    Float,
    ForeignKey,
    Index,
    LargeBinary,
    SmallInteger,
    String,
    Boolean,
    DateTime,
    Integer,
    Enum as SQLEnum,
    Table,
    Column,
    null,
)
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship
from sqlalchemy.ext.orderinglist import ordering_list

from pydantic import BaseModel, EmailStr, Field, validator, field_validator

from app.auth.models import USER_ID_T
from app.core.config import settings
from app.recipes.constants import UnitSystem, BaseUnit
from app.recipes.associations import (
    user_favorite_recipes,
    recipe_categories_association,
)
from app.recipes import constants
from app.db import Base


class RecipeCategories(Base):
    __tablename__ = "recipe_categories"
    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    name: Mapped[str] = mapped_column(String(constants.MAX_DEFAULT_NAME_LENGTH))


class FoodCandidate(Base):
    """
    Multi-lingual food suggestions
    """

    __tablename__ = "food_candidates"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    name: Mapped[str] = mapped_column(
        String(constants.MAX_DEFAULT_NAME_LENGTH), index=True
    )
    description: Mapped[str | None] = mapped_column(String)
    language: Mapped[str] = mapped_column(String(10), index=True)
    # meta
    wiki_id: Mapped[str | None] = mapped_column(String)
    openfoodfacts_id: Mapped[str | None] = mapped_column(String)
    usda_ndb_id: Mapped[str | None] = mapped_column(String)


class Unit(Base):
    __tablename__ = "units"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    name: Mapped[str] = mapped_column(
        String(constants.MAX_DEFAULT_NAME_LENGTH), nullable=False
    )
    base_unit: Mapped[BaseUnit | None] = mapped_column(SQLEnum(BaseUnit), nullable=True)
    conversion_factor: Mapped[float] = mapped_column(Float, nullable=True)
    unit_system: Mapped[UnitSystem] = mapped_column(SQLEnum(UnitSystem), nullable=False)


class Ingredient(Base):
    __tablename__ = "ingredients"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)

    amount_min: Mapped[float] = mapped_column(Float, nullable=True)
    amount_max: Mapped[float | None] = mapped_column(Float, nullable=True)
    food: Mapped[str] = mapped_column(
        String(constants.MAX_DEFAULT_NAME_LENGTH), nullable=True, index=True
    )
    comment: Mapped[str] = mapped_column(String(512), nullable=True)
    unit_id: Mapped[int] = mapped_column(
        ForeignKey("units.id", ondelete="RESTRICT"), nullable=True, index=True
    )
    unit: Mapped["Unit"] = relationship("Unit")
    position: Mapped[int] = mapped_column(Integer)

    ingredient_group_id: Mapped[int] = mapped_column(
        ForeignKey("ingredient_groups.id", ondelete="CASCADE")
    )
    # Add explicit relationship
    ingredient_group: Mapped["IngredientGroup"] = relationship(
        "IngredientGroup", back_populates="ingredients"
    )


class IngredientGroup(Base):
    __tablename__ = "ingredient_groups"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    name: Mapped[str] = mapped_column(String, nullable=True)
    position: Mapped[int] = mapped_column(Integer)

    # Ingredients in this group
    ingredients: Mapped[list["Ingredient"]] = relationship(
        "Ingredient",
        order_by="Ingredient.position",
        collection_class=ordering_list("position"),
        back_populates="ingredient_group",
        cascade="all, delete-orphan",
    )

    recipe_revision_id: Mapped[int] = mapped_column(
        ForeignKey("recipe_revisions.id", ondelete="CASCADE"), nullable=False
    )  # Back-reference to RecipeRevision
    recipe_revision: Mapped["RecipeRevision"] = relationship(
        "RecipeRevision", back_populates="ingredient_groups"
    )


class InstructionGroup(Base):
    __tablename__ = "instruction_groups"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    name: Mapped[str] = mapped_column(String, nullable=True)
    instructions: Mapped[str] = mapped_column(String, nullable=True)
    position: Mapped[int] = mapped_column(Integer)

    recipe_revision_id: Mapped[int] = mapped_column(
        ForeignKey("recipe_revisions.id", ondelete="CASCADE"), nullable=False
    )
    # Back-reference to RecipeRevision
    recipe_revision: Mapped["RecipeRevision"] = relationship(
        "RecipeRevision", back_populates="instruction_groups"
    )


class Recipe(Base):
    """This table contains the unchanging meta data about a recipe"""

    __tablename__ = "recipes"

    id: Mapped[int] = mapped_column(primary_key=True)
    owner_id: Mapped[USER_ID_T] = mapped_column(ForeignKey("users.id"), nullable=False)
    is_private: Mapped[bool] = mapped_column(Boolean, nullable=False)
    is_draft: Mapped[bool] = mapped_column(Boolean, nullable=False)
    language: Mapped[str] = mapped_column(String, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(UTC), nullable=False
    )
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
        index=True,
    )

    # Reference to the latest revision for efficiency
    latest_revision_id: Mapped[int | None] = mapped_column(
        ForeignKey("recipe_revisions.id"), nullable=True
    )

    # Relationships
    latest_revision: Mapped["RecipeRevision"] = relationship(
        "RecipeRevision", foreign_keys=[latest_revision_id], post_update=True
    )
    revisions: Mapped[list["RecipeRevision"]] = relationship(
        "RecipeRevision",
        foreign_keys="RecipeRevision.recipe_id",
        order_by="RecipeRevision.created_at.desc()",
        back_populates="recipe",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
    favorited_by = relationship(
        "User",
        secondary=user_favorite_recipes,
        back_populates="favorite_recipes",
        lazy="selectin",
    )
    __table_args__ = (
        Index(
            "ix_recipes_updated_at_desc",
            updated_at.desc(),
            id.desc(),
        ),
    )


class RecipeRevision(Base):
    __tablename__ = "recipe_revisions"

    id: Mapped[int] = mapped_column(primary_key=True)

    recipe_id: Mapped[int] = mapped_column(
        ForeignKey("recipes.id", ondelete="CASCADE"), nullable=False
    )
    title: Mapped[str] = mapped_column(
        String(constants.MAX_DEFAULT_NAME_LENGTH), nullable=True
    )
    subtitle: Mapped[str | None] = mapped_column(String, nullable=True)

    difficulty: Mapped[int] = mapped_column(SmallInteger, nullable=True)
    servings: Mapped[int | None] = mapped_column(SmallInteger, nullable=True)
    prep_time: Mapped[int | None] = mapped_column(SmallInteger, nullable=True)
    cook_time: Mapped[int | None] = mapped_column(SmallInteger, nullable=True)

    source_name: Mapped[str | None] = mapped_column(String, nullable=True)
    source_page: Mapped[str | None] = mapped_column(String, nullable=True)
    source_url: Mapped[str | None] = mapped_column(String, nullable=True)

    owner_comment: Mapped[str | None] = mapped_column(String, nullable=True)
    categories: Mapped[list["RecipeCategories"]] = relationship(
        "RecipeCategories",
        secondary=recipe_categories_association,
        lazy="joined",
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        nullable=False,
        index=True,
    )
    # is_current: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    # Relationships back to Recipe
    recipe: Mapped["Recipe"] = relationship(
        "Recipe", foreign_keys=[recipe_id], back_populates="revisions"
    )

    # Ingredient and instruction groups
    ingredient_groups: Mapped[list["IngredientGroup"]] = relationship(
        "IngredientGroup",
        order_by="IngredientGroup.position",
        collection_class=ordering_list("position"),
        # backref="recipe_revision",
        back_populates="recipe_revision",
        cascade="all, delete-orphan",
    )

    instruction_groups: Mapped[list["InstructionGroup"]] = relationship(
        "InstructionGroup",
        order_by="InstructionGroup.position",
        collection_class=ordering_list("position"),
        back_populates="recipe_revision",
        cascade="all, delete-orphan",
    )
