# Gosh AI can be great and can be shit. Translating recipes it does pretty well.
from enum import IntEnum, StrEnum, Enum
import json
from pathlib import Path
import select
import tempfile

from google import genai
import requests
from google.genai.types import GenerateContentConfig

from fastapi import UploadFile
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.recipes.models import Unit
from app.recipes.schemas import (
    IngredientBase,
    IngredientGroupBase,
    RecipeCreateUpdate,
    RecipeRevisionBase,
    RecipeRevisionCreateUpdate,
)


class LanguageCode(StrEnum):
    en = "en"
    de = "de"
    cs = "cs"
    it = "it"
    fr = "fr"
    jp = "jp"


class UnitEnum(str, Enum):
    KILOGRAM = "kilogram"
    GRAM = "gram"
    DECAGRAM = "decagram"
    MILLIGRAM = "milligram"
    MICROGRAM = "microgram"

    LITER = "liter"
    MILLILITER = "milliliter"
    CENTILITER = "centiliter"
    DECILITER = "deciliter"

    GILL_IMPERIAL = "gill (imp.)"
    GILL_US = "gill (us)"

    POUND_US = "pound (us)"
    POUND_IMPERIAL = "pound (imp.)"
    POUND_DUTCH = "pound (dt.)"

    TEASPOON = "teaspoon"
    TABLESPOON = "tablespoon"

    CUP_US = "cup (us)"
    CUP_METRIC = "cup (metric)"
    TEA_CUP = "tea cup"

    FLUID_OUNCE_IMPERIAL = "fluid ounce (imp.)"
    FLUID_OUNCE_US = "fluid ounce (us)"

    GALLON_IMPERIAL = "gallon (imp.)"
    GALLON_US = "gallon (us)"

    GRAIN = "grain"

    SALTSPOON = "saltspoon"

    SHAKU = "shaku 勺"
    GO = "gō 合"
    SHO_VOLUME = "shō 升"
    TO = "to 斗"
    KOKU = "koku 石"

    FUN = "fun 分"
    MONME = "monme 匁"
    RYO = "ryō 両"
    KIN = "kin 斤"
    KAN = "kan 貫"
    SHO_WEIGHT = "shō 鍾"

    PIECE = "piece"
    PINCH = "pinch"
    TUB = "tub"
    BUNDLE = "bundle"
    HANDFUL = "handful"
    BAG = "bag"
    CAN = "can"
    BOTTLE = "bottle"
    KNIFE_TIP = "knife tip"
    STICK = "stick"
    STEM = "stem"
    PACKAGE = "package"
    DASH = "dash"
    DROP = "drop"
    COFFEESPOON = "coffeespoon"
    SLICE = "slice"
    SPLASH = "splash"
    CLOVE = "clove"
    BULB = "bulb"

    SPECIFIC_GRAVITY = "specific gravity"
    BRIX = "brix"
    INTERNATIONAL_UNIT = "international unit"
    CALORIE = "calorie"
    KILOJOULE = "kilojoule"
    PARTS_PER_MILLION = "parts per million"

    HEAD = "head"
    TO_TASTE = "to taste"
    SHEET = "sheet"
    BLOCK = "block"


UNIT_ENUM_TO_ID = {
    UnitEnum.KILOGRAM: 1,
    UnitEnum.GRAM: 2,
    UnitEnum.DECAGRAM: 3,
    UnitEnum.MILLIGRAM: 4,
    UnitEnum.MICROGRAM: 5,
    UnitEnum.LITER: 6,
    UnitEnum.MILLILITER: 7,
    UnitEnum.CENTILITER: 8,
    UnitEnum.DECILITER: 9,
    UnitEnum.GILL_IMPERIAL: 10,
    UnitEnum.GILL_US: 11,
    UnitEnum.POUND_US: 12,
    UnitEnum.TEASPOON: 13,
    UnitEnum.TABLESPOON: 14,
    UnitEnum.PIECE: 15,
    UnitEnum.PINCH: 16,
    UnitEnum.TUB: 17,
    UnitEnum.BUNDLE: 18,
    UnitEnum.HANDFUL: 19,
    UnitEnum.BAG: 20,
    UnitEnum.CUP_US: 21,
    UnitEnum.CUP_METRIC: 22,
    UnitEnum.CAN: 23,
    UnitEnum.BOTTLE: 24,
    UnitEnum.KNIFE_TIP: 25,
    UnitEnum.STICK: 26,
    UnitEnum.STEM: 27,
    UnitEnum.PACKAGE: 28,
    UnitEnum.DASH: 29,
    UnitEnum.DROP: 30,
    UnitEnum.COFFEESPOON: 31,
    UnitEnum.GRAIN: 32,
    UnitEnum.SLICE: 33,
    UnitEnum.SPLASH: 34,
    UnitEnum.CLOVE: 35,
    UnitEnum.BULB: 36,
    UnitEnum.FLUID_OUNCE_IMPERIAL: 37,
    UnitEnum.FLUID_OUNCE_US: 38,
    UnitEnum.GALLON_IMPERIAL: 39,
    UnitEnum.GALLON_US: 40,
    UnitEnum.SALTSPOON: 41,
    UnitEnum.TEA_CUP: 42,
    UnitEnum.POUND_DUTCH: 43,
    UnitEnum.POUND_IMPERIAL: 44,
    UnitEnum.SHAKU: 45,
    UnitEnum.GO: 46,
    UnitEnum.SHO_VOLUME: 47,
    UnitEnum.TO: 48,
    UnitEnum.KOKU: 49,
    UnitEnum.FUN: 50,
    UnitEnum.MONME: 51,
    UnitEnum.RYO: 52,
    UnitEnum.KIN: 53,
    UnitEnum.KAN: 54,
    UnitEnum.SHO_WEIGHT: 55,
    UnitEnum.SPECIFIC_GRAVITY: 56,
    UnitEnum.BRIX: 57,
    UnitEnum.INTERNATIONAL_UNIT: 58,
    UnitEnum.CALORIE: 59,
    UnitEnum.KILOJOULE: 60,
    UnitEnum.PARTS_PER_MILLION: 61,
    UnitEnum.HEAD: 62,
    UnitEnum.TO_TASTE: 63,
    UnitEnum.SHEET: 64,
    UnitEnum.BLOCK: 65,
}


class RecipeCategoryEnum(str, Enum):
    BREAKFAST = "Breakfast"
    LUNCH = "Lunch"
    DINNER = "Dinner"
    BRUNCH = "Brunch"
    APPETIZER = "Appetizer"
    SALAD = "Salad"
    SOUP = "Soup"
    SIDE_DISH = "Side Dish"
    MAIN_COURSE = "Main Course"
    SNACK = "Snack"
    DESSERT = "Dessert"
    BEVERAGE = "Beverage"
    SAUCE_AND_DRESSING = "Sauce & Dressing"
    CONDIMENT = "Condiment"
    BAKING = "Baking"
    BREAD = "Bread"
    CAKES_AND_CUPCAKES = "Cakes & Cupcakes"
    COOKIES_AND_BARS = "Cookies & Bars"
    PASTRIES_AND_PIES = "Pastries & Pies"
    HOLIDAY_AND_SPECIAL_OCCASION = "Holiday & Special Occasion"


RECIPE_CATEGORY_ENUM_TO_ID = {
    RecipeCategoryEnum.BREAKFAST: 0,
    RecipeCategoryEnum.LUNCH: 1,
    RecipeCategoryEnum.DINNER: 2,
    RecipeCategoryEnum.BRUNCH: 3,
    RecipeCategoryEnum.APPETIZER: 4,
    RecipeCategoryEnum.SALAD: 5,
    RecipeCategoryEnum.SOUP: 6,
    RecipeCategoryEnum.SIDE_DISH: 7,
    RecipeCategoryEnum.MAIN_COURSE: 8,
    RecipeCategoryEnum.SNACK: 9,
    RecipeCategoryEnum.DESSERT: 10,
    RecipeCategoryEnum.BEVERAGE: 11,
    RecipeCategoryEnum.SAUCE_AND_DRESSING: 12,
    RecipeCategoryEnum.CONDIMENT: 13,
    RecipeCategoryEnum.BAKING: 14,
    RecipeCategoryEnum.BREAD: 15,
    RecipeCategoryEnum.CAKES_AND_CUPCAKES: 16,
    RecipeCategoryEnum.COOKIES_AND_BARS: 17,
    RecipeCategoryEnum.PASTRIES_AND_PIES: 18,
    RecipeCategoryEnum.HOLIDAY_AND_SPECIAL_OCCASION: 19,
}


class IngredientGeminiSchema(IngredientBase):
    unit_id: UnitEnum


class IngredientGroupGeminiSchema(IngredientGroupBase):
    ingredients: list[IngredientGeminiSchema]


class RecipeRevisionGeminiSchema(RecipeRevisionBase):
    categories: list[RecipeCategoryEnum]
    ingredient_groups: list[IngredientGroupGeminiSchema]


class RecipeGeminiSchema(BaseModel):
    language: LanguageCode
    content: RecipeRevisionGeminiSchema


PROMPT_FILE = """
Extract all recipe information from this file.

CRITICAL INSTRUCTIONS:
 - DO NOT CHANGE INGREDIENTS. Keep accurate and detailed as possible
 - Ingredients have an option "comments" field. Use this to specify things such as chopped, or specifying size such as large!
 - Keep original units as specified in the recipe. Do not perform automatic conversion!
 - If no amount is specify minimum amount as 1. Use piece or dash as unit, or whatever makes the most sense in the context.
- For instruction_groups "instructions" field: preserve ALL newlines (\\n\\n) exactly as they appear in the source
 - Each step should be separated by \\n\\n (double newline)
 - Do not write anything into owner_commment
 - If a step has preceeding number in the recipe, it can be removed. Just keep the order and the spacing with \\n\\n
 - Return structured data matching the provided schema
"""

PROMPT_URL = """
Extract all recipe information from this crawled HTML code.

CRITICAL INSTRUCTIONS:
 - DO NOT CHANGE INGREDIENTS. Keep accurate and detailed as possible
 - Ingredients have an option "comments" field. Use this to specify things such as chopped, or specifying size such as large!
 - Keep original units as specified in the recipe. Do not perform automatic conversion!
 - If no amount is specify minimum amount as 1. Use piece or dash as unit, or whatever makes the most sense in the context.
- For instruction_groups "instructions" field: preserve ALL newlines (\\n\\n) exactly as they appear in the source
 - Each step should be separated by \\n\\n (double newline)
 - Do not write anything into owner_commment
 - If a step has preceeding number in the recipe, it can be removed. Just keep the order and the spacing with \\n\\n
 - Return structured data matching the provided schema
"""


async def create_recipe_from_file(
    file: UploadFile, db: AsyncSession
) -> RecipeCreateUpdate:
    """
    Extract recipe data from a PDF file using Google GenAI with structured output.

    Args:
        file: FastAPI UploadFile object containing the PDF

    Returns:
        dict: Recipe data matching RECIPE_SCHEMA

    Raises:
        Exception: If file upload or AI processing fails
    """

    # Read file content
    content = await file.read()

    # Create a temporary file to store the PDF
    with tempfile.NamedTemporaryFile(
        delete=False, suffix=Path(file.filename).suffix
    ) as tmp_file:
        tmp_file.write(content)
        tmp_path = tmp_file.name

    try:
        # Upload file to GenAI
        async with genai.Client(api_key=settings.GEMINI_API_KEY).aio as aclient:
            uploaded_file = await aclient.files.upload(file=tmp_path)

            response = await aclient.models.generate_content(
                model="gemini-2.5-flash",
                contents=[uploaded_file, PROMPT_FILE],
                config={
                    "response_mime_type": "application/json",
                    "response_schema": RecipeGeminiSchema,
                },
            )

        out = json.loads(response.text)
        for ing in out["content"]["ingredient_groups"]:
            for ingredient in ing["ingredients"]:
                ingredient["unit_id"] = UNIT_ENUM_TO_ID[ingredient["unit_id"]]

        out["content"]["categories"] = [
            RECIPE_CATEGORY_ENUM_TO_ID[id] for id in out["content"]["categories"]
        ]
        out["is_private"] = False
        out["is_draft"] = True

        return RecipeCreateUpdate.model_validate(out)

    except Exception as e:
        raise Exception(f"Failed to create recipe from PDF: {str(e)}")


async def create_recipe_from_url(url: str, db: AsyncSession) -> RecipeCreateUpdate:
    """
    Extract recipe data from a url using Google GenAI with structured output.

    Args:
        url: URL of reicpe to process

    Returns:
        dict: Recipe data matching RECIPE_SCHEMA

    Raises:
        Exception: If file upload or AI processing fails
    """

    try:
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
                        "(KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36"
        }
        response = requests.get(url, timeout=10, headers=headers)
        response.raise_for_status()
        if response is None:
            raise Exception("Couldnt crawl URL")

        
        html = response.text

        async with genai.Client(api_key=settings.GEMINI_API_KEY).aio as aclient:

            response = await aclient.models.generate_content(
                model="gemini-2.5-flash",
                contents=[PROMPT_URL, html],
                config=GenerateContentConfig(
                    response_mime_type="application/json",
                    response_schema=RecipeGeminiSchema,
                ),
            )

        out = json.loads(response.text)
        for ing in out["content"]["ingredient_groups"]:
            for ingredient in ing["ingredients"]:
                ingredient["unit_id"] = UNIT_ENUM_TO_ID[ingredient["unit_id"]]

        out["content"]["categories"] = [
            RECIPE_CATEGORY_ENUM_TO_ID[id] for id in out["content"]["categories"]
        ]
        out["is_private"] = False
        out["is_draft"] = True

        return RecipeCreateUpdate.model_validate(out)

    except Exception as e:
        raise Exception(f"Failed to create recipe from URL: {str(e)}")
