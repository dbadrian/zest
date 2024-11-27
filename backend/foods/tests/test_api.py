import logging
from django.test import TestCase
from django.contrib.auth import get_user_model
from rest_framework import status

from shared.tools_utest import basic_response_validation, get_api_client, post, get, delete
from shared.translator import set_language
from ..models import Food


logger = logging.getLogger(__name__)
# pylint: disable=no-member

APIBASE = "/api/v1/"

class FoodAndFoodSynonomysApiTest(TestCase):
    """ foods.api.UnitViewSet """

    def setUp(self):
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
            }
        ]
        for food in self.foods:
            Food.objects.create(**food)

    def _get_response(self, args=""):
        client = get_api_client()
        response = client.get(APIBASE + f"foods/{args}")
        return response, response.data

    def test_basic_response_validation(self):
        response, _ = self._get_response()
        basic_response_validation(unittest=self, response=response, model_name="foods")

    def test_get_all_foods_summary(self):
        _, data = self._get_response()
        foods = data["foods"]
        self.assertEqual(len(foods), len(self.foods))
        
        names = [u["name"][0]["value"] for u in foods]
        lang = [u["name"][0]["lang"] for u in foods]
        # if the following fails, then most likely the ordering setting was changed
        self.assertEqual(names, ["Food1_en", "Food2_en", "Food3_de"])
        self.assertEqual(lang, ["en", "en", "de"])
        
        descriptions = [u["description"][0]["value"] for u in foods]
        lang = [u["description"][0]["lang"] for u in foods]
        # if the following fails, then most likely the ordering setting was changed
        self.assertEqual(descriptions, ["Desc1_en", "Desc2_en", "Desc3_de"])
        self.assertEqual(lang, ["en", "en", "de"])
        
    def test_translation(self):
        resp, data = self._get_response(args="?lang=de")
        basic_response_validation(unittest=self, response=resp, model_name="foods")

        foods = data["foods"]
        names = [u["name"][0]["value"] for u in foods]
        lang = [u["name"][0]["lang"] for u in foods]
        # if the following fails, then most likely the ordering setting was changed
        self.assertEqual(names, ["Food1_de", "Food2_de", "Food3_de"])
        self.assertEqual(lang, ["de", "de", "de"])
        
        descriptions = [u["description"][0]["value"] for u in foods]
        lang = [u["description"][0]["lang"] for u in foods]
        # if the following fails, then most likely the ordering setting was changed
        self.assertEqual(descriptions, ["Desc1_de", "Desc2_en", "Desc3_de"])
        self.assertEqual(lang, ["de", "en", "de"])

    def test_creation_without_language_param(self):
        client = get_api_client()

        response = post(client, "foods/", data={"name": [{"value": "food_new_en", "lang": "en"}]})
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        data = response.data
        self.assertEqual(data["name"][0]["value"], "food_new_en")
        self.assertEqual(data["name"][0]["lang"], "en")
        
        # explicitly set the language
        response = post(client, "foods/", data={"name": [{"value": "food_new_en2", "lang": "en"}]})
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        data = response.data
        self.assertEqual(data["name"][0]["value"], "food_new_en2")
        self.assertEqual(data["name"][0]["lang"], "en")

        response = post(client, "foods/", data={"name": [{"value": "food_new_de", "lang": "de"}]})
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        data = response.data
        self.assertEqual(data["name"][0]["value"], "food_new_de")
        self.assertEqual(data["name"][0]["lang"], "de")
        
        response = post(client, "foods/", data={"name": [{"value": "food_new_de3", "lang": "de"}, {"value": "food_new_en3", "lang": "en"}]})
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        data = response.data
        # english set to prefered language as no arg is given
        self.assertEqual(data["name"][0]["value"], "food_new_en3")
        self.assertEqual(data["name"][0]["lang"], "en")

        response = post(client, "foods/?lang=de", data={"name": [{"value": "food_new_de4", "lang": "de"}, {"value": "food_new_en4", "lang": "en"}]})
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        data = response.data
        # english set to prefered language as no arg is given
        self.assertEqual(data["name"][0]["value"], "food_new_de4")
        self.assertEqual(data["name"][0]["lang"], "de")
        

    def test_only_admin_can_delete(self):
        food_id = Food.objects.all()[0].id
        client = get_api_client()
        response = delete(client, f"foods/{food_id}/")
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        
    def test_filter_by_list_of_pks(self):
        _f = Food.objects.all()
        food_ids = [_f[0].id, _f[2].id]
        
        _, data = self._get_response()
        foods = data["foods"]
        self.assertEqual(len(foods), len(self.foods))
        
        _, data = self._get_response(args=f"?pks={','.join([str(f) for f in food_ids])}")
        foods = data["foods"]
        self.assertEqual(len(foods), len(food_ids))
        for idx, food in enumerate(foods):
            self.assertEqual(food["id"], str(food_ids[idx]))
            
        # order is ignored, as it orderes automatically
        _, data = self._get_response(args=f"?pks={','.join([str(f) for f in food_ids][::-1])}")
        foods = data["foods"]
        self.assertEqual(len(foods), len(food_ids))
        for idx, food in enumerate(foods):
            self.assertEqual(food["id"], str(food_ids[idx]))

    ## Food synonym related
    def test_create_synonym(self):
        client = get_api_client()
        for idx, f in enumerate(Food.objects.all()):
            food_id = f.id
            response = post(client, "food_synonyms/", data={
                "name": f"FS_{idx}",
                "language": "en",
                "food": str(food_id),
            })
            self.assertEqual(response.status_code, status.HTTP_201_CREATED)
            data = response.data
            data.pop("id")
            data.pop("similarity")
            self.assertDictEqual(
                data, 
                {
                    "name": f"FS_{idx}",
                    "language": "en",
                    "food": food_id,
                }
            )
