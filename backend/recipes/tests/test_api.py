import logging
from django.test import TestCase
from django.contrib.auth import get_user_model
from rest_framework import status
import random
import string

from shared.tools_utest import basic_response_validation, get_api_client, post
from shared.translator import set_language
from units.models import Unit
from ..models import Recipe, RecipeCategory
from foods.models import Food


logger = logging.getLogger(__name__)
# pylint: disable=no-member

APIBASE = "/api/v1/"


class RecipeApiTest(TestCase):
    """Recipe.api.RecipeViewSet"""

    # "servings": request.query_params.get("servings"),
    # "to_metric": False if request.query_params.get("to_metric") is None else True,
    # "lang": request.query_params.get("lang"),
    # create
    # delete

    def setUp(self):
        User = get_user_model()
        self.user_1 = User.objects.create_user(
            username="recipeuser1",
            email="user1@ilikecooking.com",
            password="testpass123",
        )
        self.user_2 = User.objects.create_user(
            username="recipeuser2",
            email="user2@ilikecooking.com",
            password="testpass123",
        )

        self.recipes = [
            {
                "owner": self.user_1,
                "title": "Title1",
                "subtitle": "Subtitle1",
                "owner_comment": "OwnerComment1",
                "language": "de",
                "private": False,
                "servings": 1,
                "prep_time": 1,
                "cook_time": 1,
                "source_name": "Source1",
                "source_page": 1,
                "source_url": "https://www.google.com/search/recipe1",
                "difficulty": 1,
            },
            {
                "owner": self.user_1,
                "title": "Title2",
                "subtitle": "Subtitle2",
                "owner_comment": "OwnerComment2",
                "language": "de",
                "private": False,
                "servings": 2,
                "prep_time": 2,
                "cook_time": 2,
                "source_name": "Source2",
                "source_page": 2,
                "source_url": "https://www.google.com/search/recipe2",
                "difficulty": 1,
            },
            {
                "owner": self.user_2,
                "title": "Title3",
                "subtitle": "Subtitle3",
                "owner_comment": "OwnerComment3",
                "language": "de",
                "private": False,
                "servings": 3,
                "prep_time": 3,
                "cook_time": 3,
                "source_name": "Source3",
                "source_page": 3,
                "source_url": "https://www.google.com/search/recipe3",
                "difficulty": 3,
            },
            {
                "owner": self.user_2,
                "title": "Title4",
                "subtitle": "Subtitle4",
                "owner_comment": "OwnerComment4",
                "language": "de",
                "private": True,
                "servings": 4,
                "prep_time": 4,
                "cook_time": 4,
                "source_name": "Source4",
                "source_page": 4,
                "source_url": "https://www.google.com/search/recipe4",
                "difficulty": 3,
            },
        ]
        for r in self.recipes:
            Recipe.objects.create(**r)

        # copy pasta from foods unit test...kinda meh, but oh well
        self.foods = [
            {
                "name_en": "Food1_en",
                "name_de": "Food1_de",
                "wiki_id": "QWIKIID_1",
                "openfoodfacts_key": "OFF_1",
                "usda_nbd_ids": "USDA_1",
                "description_en": "Desc1_en",
                "description_de": "Desc1_de",
            },
            {
                "name_en": "Food2_en",
                "name_de": "Food2_de",
                "wiki_id": "QWIKIID_2",
                "openfoodfacts_key": "OFF_2",
                "usda_nbd_ids": "USDA_2",
                "description_en": "Desc2_en",
            },
            {
                "name_de": "Food3_de",
                "wiki_id": "QWIKIID_3",
                "openfoodfacts_key": "OFF_3",
                "usda_nbd_ids": "USDA_3",
                "description_de": "Desc3_de",
            },
        ]
        for food in self.foods:
            Food.objects.create(**food)
        self.units = [
            {"name_en": "Unit1", "name_de": "Unit1_de"},
            {
                "name_en": "Unit2",
            },
            {
                "name_en": "Unit3",
            },
            {
                "name_en": "kilogram",
                "name_de": "kilogram_de",
                "name_plural_en": "kilograms",
                "abbreviation_en": "kg",
                "base_unit": "kg",
                "conversion_factor": "1",
                "unit_system": "Metric",
            },
        ]
        for unit in self.units:
            Unit.objects.create(**unit)

    def _get_response(self, args=""):
        client = get_api_client()
        response = client.get(APIBASE + f"recipes/{args}")
        return response, response.data

    def test_basic_response_validation(self):
        response, _ = self._get_response()
        basic_response_validation(
            unittest=self, response=response, model_name="recipes"
        )

    def test_get_all_recipes_summary(self):
        _, data = self._get_response()
        recipes = data["recipes"]
        self.assertEqual(
            len(recipes), len([r for r in self.recipes if not r["private"]])
        )

    def test_creation_minimal_example(self):
        client = get_api_client()
        response = post(
            client,
            "recipes/",
            data={
                "title": "Title4",
                "servings": 4,
                "category": [1],
                # "prep_time": 4,
                "cook_time": 4,
                "language": "de",
                "ingredient_groups": [],
                "instruction_groups": [],
                # HAS DEFAULT: "private": True,
                "owner_comment": "OwnerComment1",
                #                "private": False,
                "source_name": "Source1",
                "source_page": 1,
                "source_url": "https://www.google.com/search/recipe1",
                "difficulty": 1,
            },
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)

    def test_creation_insufficient_minimal_example(self):
        client = get_api_client()
        response = post(client, "recipes/", data={})
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_creation_full_recipe_example(self):
        client = get_api_client()
        f = Food.objects.all()
        u = Unit.objects.all()
        response = post(
            client,
            "recipes/",
            data={
                "title": "ATitle",
                "subtitle": "ASubtitle",
                "language": "de",
                "owner_comment": "Comment",
                "private": False,
                "difficulty": 2,
                "servings": 4,
                "prep_time": 52,
                "cook_time": 12,
                "category": [1, 3, 5, 6],
                "source_name": "SOurce11",
                "source_page": 33,
                "source_url": "https://en.wikipedia.org/wiki/Mindless_Self_Indulgence",
                "ingredient_groups": [
                    {
                        "name": "First Ingredient Group",
                        "ingredients": [
                            {
                                "amount": "23",
                                "amount_max": "333.0009",
                                "unit": {"id": str(u[1].id)},
                                "food": {"id": str(f[1].id)},
                            },
                            {
                                "amount": "23",
                                "unit": {"id": str(u[2].id)},
                                "food": {"id": str(f[2].id)},
                            },
                        ],
                    },
                    {
                        "name": "Second Ingredient Group",
                        "ingredients": [
                            {
                                "amount": "1",
                                "amount_max": "2.0",
                                "unit": {"id": str(u[0].id)},
                                "food": {"id": str(f[0].id)},
                            }
                        ],
                    },
                ],
                "instruction_groups": [
                    {
                        "name": "A first instruction group",
                        "instructions": [
                            {"text": "first instruction of first group"},
                            {"text": "second instruction of first group"},
                            {"text": "third instruction of first group"},
                            {"text": "fourth instruction of first group"},
                        ],
                    },
                    {
                        "name": "A second instruction group",
                        "instructions": [
                            {"text": "first instruction of second group"},
                            {"text": "second instruction of second group"},
                        ],
                    },
                ],
                # skipping tags...so not totally complete
            },
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)


class RecipeVersionListViewApiTest(TestCase):
    """Recipe.api.RecipeVersionListView"""

    def setUp(self):
        pass


class RecipeCategoryViewSetViewApiTest(TestCase):
    """Recipe.api.RecipeVersionListView"""

    def setUp(self):
        pass
