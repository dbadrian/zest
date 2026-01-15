import sys
import asyncio
import random
from datetime import datetime, UTC
from typing import Sequence

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy import select

from app.core.config import settings
from app.db import Base
from app.auth.models import User
from app.recipes.models import (
    Recipe,
    RecipeRevision,
    IngredientGroup,
    Ingredient,
    InstructionGroup,
    RecipeCategories,
    Unit,
)
from app.recipes.schemas import (
    MIN_DIFFICULTY,
    MAX_DIFFICULTY,
    MIN_SERVINGS,
    MAX_SERVINGS,
    MAX_TIME_MINUTES,
)

# ------------------------------------------------------------------
# CONFIG
# ------------------------------------------------------------------

DATABASE_URL = str(settings.SQLALCHEMY_DATABASE_URI)  # async (postgresql+asyncpg://)

# ------------------------------------------------------------------
# HUGE DATA CORPUS
# ------------------------------------------------------------------

PROTEINS = [
    "Chicken Breast",
    "Chicken Thigh",
    "Turkey",
    "Ground Beef",
    "Beef Steak",
    "Pork Shoulder",
    "Pork Belly",
    "Bacon",
    "Salmon",
    "Tilapia",
    "Shrimp",
    "Scallops",
    "Tofu",
    "Tempeh",
    "Seitan",
    "Lentils",
    "Chickpeas",
    "Black Beans",
    "Kidney Beans",
    "Eggs",
    "Quail Eggs",
]

VEGETABLES = [
    "Tomato",
    "Onion",
    "Garlic",
    "Carrot",
    "Celery",
    "Bell Pepper",
    "Spinach",
    "Kale",
    "Mushroom",
    "Potato",
    "Sweet Potato",
    "Zucchini",
    "Cucumber",
    "Eggplant",
    "Broccoli",
    "Cauliflower",
    "Brussels Sprouts",
    "Leek",
    "Asparagus",
    "Green Beans",
]

FRUITS = [
    "Apple",
    "Banana",
    "Lemon",
    "Lime",
    "Orange",
    "Blueberry",
    "Strawberry",
    "Raspberry",
    "Mango",
    "Pineapple",
    "Peach",
    "Pear",
    "Cherry",
    "Grapes",
    "Pomegranate",
    "Avocado",
    "Coconut",
    "Dates",
    "Raisins",
]

DAIRY = [
    "Milk",
    "Butter",
    "Cream",
    "Yogurt",
    "Cheddar Cheese",
    "Mozzarella",
    "Parmesan",
    "Feta Cheese",
    "Goat Cheese",
]

GRAINS = [
    "Rice",
    "Brown Rice",
    "Quinoa",
    "Oats",
    "Pasta",
    "Spaghetti",
    "Fusilli",
    "Bread",
    "Flour",
    "Cornmeal",
    "Couscous",
    "Polenta",
]

NUTS_SEEDS = [
    "Almonds",
    "Walnuts",
    "Cashews",
    "Pine Nuts",
    "Pumpkin Seeds",
    "Sesame Seeds",
]

HERBS_SPICES = [
    "Basil",
    "Thyme",
    "Rosemary",
    "Parsley",
    "Cilantro",
    "Dill",
    "Oregano",
    "Paprika",
    "Chili Powder",
    "Cumin",
    "Coriander",
    "Turmeric",
    "Ginger",
    "Garlic Powder",
    "Onion Powder",
    "Cinnamon",
    "Nutmeg",
    "Cloves",
    "Saffron",
]

SAUCES = [
    "Olive Oil",
    "Soy Sauce",
    "Vinegar",
    "Honey",
    "Mustard",
    "Tomato Sauce",
    "Mayonnaise",
    "Ketchup",
    "Sriracha",
    "BBQ Sauce",
    "Worcestershire Sauce",
    "Coconut Milk",
    "Fish Sauce",
    "Tahini",
]

FOODS = (
    PROTEINS + VEGETABLES + FRUITS + DAIRY + GRAINS + NUTS_SEEDS + HERBS_SPICES + SAUCES
)

ADJECTIVES = [
    "Spicy",
    "Sweet",
    "Savory",
    "Tangy",
    "Zesty",
    "Crispy",
    "Creamy",
    "Cheesy",
    "Hearty",
    "Quick",
    "Easy",
    "Classic",
    "Gourmet",
    "Smoky",
    "Glazed",
    "Rustic",
    "Indulgent",
    "Light",
    "Fresh",
    "Fiery",
    "Sizzling",
    "Golden",
]

COOKING_METHODS = [
    "Grilled",
    "Baked",
    "Fried",
    "Roasted",
    "Slow-Cooked",
    "Sautéed",
    "Steamed",
    "Poached",
    "Stir-Fried",
    "Braised",
    "Pan-Seared",
    "Glazed",
]

CUISINES = [
    "Italian",
    "Mexican",
    "Thai",
    "Indian",
    "French",
    "Chinese",
    "Japanese",
    "Mediterranean",
    "American",
    "Greek",
    "Spanish",
    "Middle Eastern",
]

FLAVORS = [
    "Garlic",
    "Lemon",
    "Herbs",
    "Honey",
    "Chili",
    "Coconut",
    "Spices",
    "Creamy Sauce",
    "Tomato",
    "Cheese",
    "Butter",
    "Mustard",
    "Ginger",
]

INGREDIENT_GROUP_NAMES = [
    "Main Ingredients",
    "Sauce Ingredients",
    "Marinade",
    "Toppings",
    "Spices & Seasonings",
    "Optional Garnish",
]

INSTRUCTION_VERBS = [
    "Bake",
    "Fry",
    "Roast",
    "Grill",
    "Sauté",
    "Steam",
    "Poach",
    "Simmer",
    "Blend",
    "Whisk",
    "Mix",
    "Marinate",
    "Toast",
    "Combine",
]

PREP_METHODS = [
    "chop",
    "dice",
    "slice",
    "mince",
    "marinate",
    "toast",
    "blend",
    "whisk",
    "fold",
    "knead",
    "grate",
    "peel",
]

INSTRUCTION_TEMPLATES = [
    "Preheat the oven to {temp}°C (or 350°F).",
    "Chop all {ingredient} into bite-sized pieces.",
    "Sauté {ingredient} in {fat} until fragrant.",
    "Add {ingredient} and {verb} for {time} minutes.",
    "Combine {ingredients} in a bowl and mix well.",
    "Garnish with {ingredient} before serving.",
    "Let the dish rest for {time} minutes before serving.",
    "Marinate {ingredient} for at least {time} minutes.",
]

# ------------------------------------------------------------------
# HELPERS
# ------------------------------------------------------------------


def random_recipe_title() -> str:
    return f"{random.choice(ADJECTIVES)} {random.choice(COOKING_METHODS)} {random.choice(PROTEINS + VEGETABLES)} with {random.choice(FLAVORS)} ({random.choice(CUISINES)} Style)"


def random_food() -> str:
    return random.choice(FOODS)


def random_ingredient_group_name() -> str:
    return random.choice(INGREDIENT_GROUP_NAMES)


def random_unit(units) -> int:
    return random.choice(units).id


def random_amount() -> tuple[float, float | None]:
    amount_min = round(random.uniform(0.5, 5.0), 2)
    if random.choice([True, False]):
        return amount_min, round(amount_min + random.uniform(0.1, 3.0), 2)
    return amount_min, None


def random_time() -> int:
    return random.randint(5, min(120, MAX_TIME_MINUTES))


def random_instruction() -> str:
    template = random.choice(INSTRUCTION_TEMPLATES)
    return template.format(
        temp=random.randint(160, 220),
        ingredient=random_food(),
        fat=random.choice(["olive oil", "butter", "vegetable oil"]),
        verb=random.choice(INSTRUCTION_VERBS),
        time=random.randint(5, 30),
        ingredients=", ".join([random_food() for _ in range(random.randint(2, 4))]),
    )


# ------------------------------------------------------------------
# GENERATOR
# ------------------------------------------------------------------


async def generate_dummy_recipes(
    *,
    db: AsyncSession,
    owner: User,
    categories: Sequence[RecipeCategories],
    units: Sequence[Unit],
    n: int,
    batch_size: int = 500,
) -> None:
    """Generate n highly diverse recipes in batches to avoid memory issues."""

    for batch_start in range(0, n, batch_size):
        recipes: list[Recipe] = []

        for i in range(batch_start, min(batch_start + batch_size, n)):
            recipe = Recipe(
                owner_id=owner.id,
                is_private=random.choice([True, False]),
                is_draft=random.choice([True, False]),
                language=random.choice(["de", "en", "cs"]),
                created_at=datetime.now(UTC),
            )

            revision = RecipeRevision(
                recipe=recipe,
                title=random_recipe_title(),
                subtitle=f"Auto-generated recipe #{i + 1}",
                difficulty=random.randint(MIN_DIFFICULTY, MAX_DIFFICULTY),
                servings=random.randint(MIN_SERVINGS, min(8, MAX_SERVINGS)),
                prep_time=random_time(),
                cook_time=random_time(),
                categories=random.sample(
                    list(categories),
                    k=random.randint(1, min(3, len(categories))),
                ),
                created_at=datetime.now(UTC),
            )

            # Ingredient Groups
            for pos_i in range(random.randint(1, 4)):
                ingredient_group = IngredientGroup(
                    name=random_ingredient_group_name(),
                    position=pos_i,
                    recipe_revision=revision,
                )
                for pos in range(random.randint(3, 8)):
                    amount_min, amount_max = random_amount()
                    Ingredient(
                        food=random_food(),
                        amount_min=amount_min,
                        amount_max=amount_max,
                        unit_id=random_unit(units),
                        position=pos,
                        ingredient_group=ingredient_group,
                    )

            # Instruction Groups
            for pos_i in range(random.randint(2, 5)):
                instructions = "\n\n".join(
                    random_instruction() for _ in range(random.randint(2, 5))
                )
                InstructionGroup(
                    name=f"Step {pos_i + 1}",
                    instructions=instructions,
                    position=pos_i,
                    recipe_revision=revision,
                )

            recipe.latest_revision = revision
            db.add(recipe)
            recipes.append(recipe)

        await db.commit()
        print(
            f"✅ Inserted recipes {batch_start + 1} to {min(batch_start + batch_size, n)}"
        )


# ------------------------------------------------------------------
# MAIN
# ------------------------------------------------------------------


async def main(n: int = 10000) -> None:
    engine = create_async_engine(DATABASE_URL, echo=False)
    async_session = async_sessionmaker(engine, expire_on_commit=False)

    async with async_session() as db:
        # --- Load dependencies ---
        user = (await db.execute(select(User).limit(1))).scalar_one()
        categories = (await db.execute(select(RecipeCategories))).scalars().all()
        units = (await db.execute(select(Unit))).scalars().all()

        if not categories or not units:
            raise RuntimeError("Units and categories must exist before seeding recipes")

        await generate_dummy_recipes(
            db=db, owner=user, categories=categories, units=units, n=n
        )

    await engine.dispose()


# ------------------------------------------------------------------
# ENTRYPOINT
# ------------------------------------------------------------------

if __name__ == "__main__":
    count = 1000
    if len(sys.argv) == 2:
        count = int(sys.argv[1])

    asyncio.run(main(count))
