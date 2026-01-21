from sqlalchemy import Table, Column, Integer, ForeignKey, Uuid
from app.db import Base

user_favorite_recipes = Table(
    "user_favorite_recipes",
    Base.metadata,
    Column("user_id", Uuid, ForeignKey("users.id"), primary_key=True),
    Column("recipe_id", Integer, ForeignKey("recipes.id"), primary_key=True),
)


# many to many association
recipe_categories_association = Table(
    "recipe_categories_association",
    Base.metadata,
    Column(
        "recipe_id",
        ForeignKey("recipe_revisions.id", ondelete="CASCADE"),
        primary_key=True,
    ),
    Column(
        "category_id",
        ForeignKey("recipe_categories.id", ondelete="CASCADE"),
        primary_key=True,
    ),
)
