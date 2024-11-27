import logging
from django.test import TestCase
from django.db import IntegrityError, transaction
from django.conf import settings
from rest_framework.test import (
    APIRequestFactory,)  # https://stackoverflow.com/questions/61350340/unit-test-serializer-django-rest-framework

from shared.translator import set_language

from ..models import Tag
from ..serializers import TagSerializer

logger = logging.getLogger(__name__)

# pylint: disable=no-member

# class TagSerializerTest(TestCase):
# """ tags.serializers.TagSerializer """

#     def setUp(self):
#         self.tag_texts = [  # dont use any duplicate values!
#             "Italian-Cusine",
#             "Turkish-Cusine",
#             "Desert",
#             "Party-Food",
#             "Summer",
#         ]
#         self.objs = [Tag.objects.create(text_en=tag, text_de=tag + "_de") for tag in self.tag_texts]
#         self.serializers = [TagSerializer(instance=obj) for obj in self.objs]

#     def test_contains_expected_fields(self):
#         """Test that expected fields are contained"""
#         for s in self.serializers:
#             self.assertCountEqual(s.data.keys(), {"id", "text"})
#             # TODO should be moved to TranslationModelSerializer tests!
#             self.assertTrue(isinstance(s.data["text"], list))
#             self.assertTrue(isinstance(s.data["text"][0], dict))
#             self.assertCountEqual(s.data["text"][0], {"value", "lang"})

#     def test_text_field_content(self):
#         """Test that text field contains multi-lingual base representation"""
#         set_language("en")

#         for idx, s in enumerate(self.serializers):
#             self.assertDictEqual(s.data["text"][0], {"value": self.tag_texts[idx], "lang": "en"})

#     def test_deserialization_from_mlr_existing_tags_deduplication(self):
#         """Deserialize multi-lingual base representation with existing match (deduplication)"""
#         set_language("en")

#         def _test_impl(data, expected, idx):
#             s = TagSerializer(data=data)
#             self.assertTrue(s.is_valid())
#             self.assertDictEqual(s.validated_data, expected | {"id": self.objs[idx].id})

#         for idx, tag in enumerate(self.tag_texts):
#             # dict representation: single
#             data = {"text": [{"value": tag, "lang": "en"}]}
#             _test_impl(data, {"text_en": tag}, idx)
#             # direct field representation: single (alt lang_)
#             data = {"text_de": tag + "_de"}
#             _test_impl(data, {"text_de": tag + "_de"}, idx)
#             # dict representation: multi
#             data = {
#                 "text": [
#                     {
#                         "value": tag + "_de",
#                         "lang": "de"
#                     },
#                     {
#                         "value": tag,
#                         "lang": "en"
#                     },
#                 ]
#             }
#             _test_impl(data, {"text_en": tag, "text_de": tag + "_de"}, idx)
#             # mixed
#             data = {"text": [{"value": tag, "lang": "en"}], "text_de": tag + "_de"}
#             _test_impl(data, {"text_en": tag, "text_de": tag + "_de"}, idx)
#             # direct field representation: multi
#             data = {"text_en": tag, "text_de": tag + "_de"}
#             _test_impl(data, {"text_en": tag, "text_de": tag + "_de"}, idx)

#     def test_deserialization_from_mlr_max_length_violation(self):
#         """Deserialize multi-lingual base representation violating the TAX_MAX_CHARS limitation"""
#         set_language("en")

#         # dict representation
#         TOOLONGTAG = "L" * (settings.TAG_MAX_CHARS + 10)

#         def _test_impl(data):
#             s = TagSerializer(data=data)
#             s.is_valid()
#             self.assertFalse(s.is_valid())

#         data = {"text": [{"value": TOOLONGTAG, "lang": "en"}]}
#         _test_impl(data)

#         data = {
#             "text": [
#                 {
#                     "value": TOOLONGTAG,
#                     "lang": "de"
#                 },
#                 {
#                     "value": TOOLONGTAG,
#                     "lang": "en"
#                 },
#             ]
#         }
#         _test_impl(data)

#         data = {"text": [{"value": TOOLONGTAG, "lang": "en"}], "text_en": TOOLONGTAG}
#         _test_impl(data)

#         data = {"text_en": "asds", "text_de": TOOLONGTAG}
#         _test_impl(data)

#     def test_deserialization_from_mlr_new_tags(self):
#         """Deserialize multi-lingual base representation without existing match"""
#         set_language("en")

#         def _test_impl(data, expected):
#             s = TagSerializer(data=data)
#             self.assertTrue(s.is_valid())
#             self.assertDictEqual(s.validated_data, expected)
#             self.assertTrue("id" not in s.validated_data)

#         # dict representation
#         for tag in ["what", "everis", "thisnewcooldjangostuff"]:
#             data = {"text": [{"value": tag, "lang": "en"}]}
#             _test_impl(data, {"text_en": tag})

#         # direct field representation
#         for tag in ["what", "everis", "thisnewcooldjangostuff"]:
#             data = {"text_en": tag}
#             s = TagSerializer(data=data)
#             _test_impl(data, {"text_en": tag})

#     def test_deserialization_from_mlr_new_tags_alt_lang(self):
#         """Deserialize multi-lingual base representation without existing match and multiple languages"""
#         set_language("de")
#         for tag in ["what", "everis", "thisnewcooldjangostuff"]:
#             data = {"text": [{"value": tag, "lang": "de"}], "text_en": tag + "_en"}
#             s = TagSerializer(data=data)
#             self.assertTrue(s.is_valid())
#             self.assertDictEqual(s.validated_data, {"text_de": tag, "text_en": tag + "_en"})
#             self.assertTrue("id" not in s.validated_data)

#     def test_deserialize_update_to_existing_tags(self):
#         set_language("en")
#         # dict representation
#         for idx, tag in enumerate(self.tag_texts):
#             data = {
#                 "id": self.objs[idx].id,
#                 "text": [{
#                     "value": tag + "_mod",
#                     "lang": "en"
#                 }],
#             }
#             s = TagSerializer(data=data)
#             self.assertTrue(s.is_valid())
#             self.assertDictEqual(s.validated_data, {"text_en": tag + "_mod", "id": self.objs[idx].id})
#             # with transaction.atomic():
#             s.save()
#             self.assertEqual(Tag.objects.get(id=self.objs[idx].id).text_en, tag + "_mod")

#     def test_deserialize_update_to_existing_tag_with_conflict(self):
#         set_language("en")
#         # dict representation
#         for idx, tag in enumerate(self.tag_texts):
#             data = {
#                 "id":
#                     self.objs[(idx + 2) % len(self.tag_texts)  # update some tag with text of other existing tag
#                              ].id,  # use a shifted version
#                 "text": [{
#                     "value": tag,
#                     "lang": "en"
#                 }],
#             }
#             s = TagSerializer(data=data)
#             self.assertFalse(s.is_valid())

#     def test_deserialize_new_tag_with_conflict(self):
#         set_language("en")
#         # dict representation
#         for tag in self.tag_texts:
#             data = {"text_en": tag, "text_de": "willnotmatchforsure:)"}
#             s = TagSerializer(data=data)
#             self.assertFalse(s.is_valid())
