from django.test import TestCase
from django.db import IntegrityError, transaction

from ..models import Tag


class TagModelTest(TestCase):
    """ tags.models.Tag """

    def setUp(self):
        self.obj = Tag.objects.create(text="Italian-Cusine")

    def test_tag_setup(self):
        self.assertEqual(self.obj.text, "Italian-Cusine")

    # def test_unit_unique_name_plural(self):
    #     """Test uniqueness contraint for pair (name_plural, unit_system)"""
    #     try:
    #         with transaction.atomic():
    #             Unit.objects.create(
    #                 name="Unit2",
    #                 name_plural="Units",
    #                 abbreviation="11",
    #                 base_unit=Unit.SIBaseUnits.KILOGRAM[0],
    #                 conversion_factor=1,
    #                 unit_system=Unit.UnitSystem.METRIC,
    #             )
    #         self.fail("Duplicated `abbreviation` constraint failed")
    #     except IntegrityError:
    #         pass

    #     Unit.objects.create(
    #         name="Unit2",
    #         name_plural="Units",
    #         abbreviation="11",
    #         base_unit=Unit.SIBaseUnits.KILOGRAM[0],
    #         conversion_factor=1,
    #         unit_system=Unit.UnitSystem.US,
    #     )
