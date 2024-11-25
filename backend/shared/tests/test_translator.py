from django.test import TestCase
from django.db import IntegrityError, transaction
from rest_framework import serializers

from ..utils.generic import contains_keys
from ..translator import from_multilanguage_representation


class TranslatorTest(TestCase):
    """shared.translator"""

    def test_from_multilanguage_representation_empty(self):
        out = from_multilanguage_representation("testfield", [])
        self.assertDictEqual(out, {})

    def test_from_multilanguage_representation_single(self):
        single = [{
            "value": "Tomato",
            "lang": "en",
        }]
        out = from_multilanguage_representation("testfield", single)
        self.assertDictEqual(out, {"testfield_en": "Tomato"})

    def test_from_multilanguage_representation_multi(self):
        triple = [
            {
                "value": "Tomato",
                "lang": "en",
            },
            {
                "value": "Tomate",
                "lang": "de",
            },
            {
                "value": "Tomata",
                "lang": "it?",
            },
        ]
        out = from_multilanguage_representation("testfield", triple)
        self.assertDictEqual(
            out,
            {
                "testfield_en": "Tomato",
                "testfield_de": "Tomate",
                "testfield_it?": "Tomata",
            },
        )

    def test_from_multilanguage_representation_malformed_input(self):
        malformed = [{}]
        with self.assertRaises(serializers.ValidationError):
            from_multilanguage_representation("testfield", malformed)

        malformed = [{"value": "Tomato"}]
        with self.assertRaises(serializers.ValidationError):
            from_multilanguage_representation("testfield", malformed)

        malformed = [{"lang": "en"}]
        with self.assertRaises(serializers.ValidationError):
            from_multilanguage_representation("testfield", malformed)
