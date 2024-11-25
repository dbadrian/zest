import logging
from django.test import TestCase
from django.contrib.auth import get_user_model
from rest_framework import status

from shared.tools_utest import basic_response_validation, get_api_client
from shared.translator import set_language
from ..models import Unit
from ..serializers import UnitSerializer

logger = logging.getLogger(__name__)
# pylint: disable=no-member

APIBASE = "/api/v1/"


class UnitApiTest(TestCase):
    """units.api.UnitViewSet"""

    def setUp(self):
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
        response = client.get(APIBASE + f"units/{args}")
        return response, response.data

    def test_basic_response_validation(self):
        response, _ = self._get_response()
        basic_response_validation(unittest=self, response=response, model_name="units")

    def test_get_all_units(self):
        _, data = self._get_response()
        units = data["units"]
        self.assertEqual(len(units), len(self.units))

        names = [u["name"][0]["value"] for u in units]
        lang = [u["name"][0]["lang"] for u in units]
        # if the following fails, then most likely the ordering setting was changed
        self.assertEqual(names, ["kilogram", "Unit1", "Unit2", "Unit3"])
        self.assertEqual(lang, ["en", "en", "en", "en"])

    def test_translation_test(self):
        resp, data = self._get_response(args="?lang=de")
        basic_response_validation(unittest=self, response=resp, model_name="units")

        units = data["units"]
        names = [u["name"][0]["value"] for u in units]
        lang = [u["name"][0]["lang"] for u in units]
        # if the following fails, then most likely the ordering setting was changed
        # the Unit2/Unit3 should say en due to fallback
        self.assertEqual(names, ["kilogram_de", "Unit1_de", "Unit2", "Unit3"])
        self.assertEqual(lang, ["de", "de", "en", "en"])

    def test_check_fields(self):
        resp, data = self._get_response()
        basic_response_validation(unittest=self, response=resp, model_name="units")

        # there are a bunch of automatically computed fields, lets check if they are "all" present
        units = data["units"]

        # all of the fields to check  which are read-only and should always be fined
        fields = [
            "id",
            "name",
            # computed ones
            "has_conversion",
            "is_metric",
            "is_imperial",
            "is_us",
        ]

        for u in units:
            for f in fields:
                self.assertIn(f, u)

        # for last unit we can check a bit more
        unit_kg = units[0]
        for f in fields + [
            "name_plural",
            "abbreviation",
            "base_unit",
            "conversion_factor",
            "unit_system",
        ]:
            self.assertIn(
                f, unit_kg
            )  # This might break if ordering changes! SHit test...
