from collections.abc import Collection
import uuid
from django.core.exceptions import ValidationError
from django.utils.translation import gettext_lazy as _
from django.db import models

from django.contrib.postgres.indexes import GinIndex
# from django.contrib.postgres.search import SearchVectorField
# from shared.translator import get_fields_with_lang_extension

from shared.utils.generic import check_dependent_fields
from units.models import Unit
from zest.settings.base.i18n import LANGUAGES

""" 
The idea is as follows:
    Food: Main definition
    
    Against food we link with:
        - Synonyms for this food (which includes the original word)
        - 
"""


class Food(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(
        _("Name"), max_length=150, unique=False, blank=False, null=False
    )

    wiki_id = models.CharField(
        _("Wikidata ID"), max_length=20, unique=True, blank=True, null=True
    )
    openfoodfacts_key = models.CharField(
        _("OpenFoodFacts Key"), max_length=150, unique=True, blank=True, null=True
    )
    usda_nbd_ids = models.CharField(
        _("USDA NBD Number"), max_length=200, unique=False, blank=True, null=True
    )
    description = models.TextField(
        _("Description"), unique=False, blank=True, null=True
    )

    class Meta:
        verbose_name = _("Food")
        verbose_name_plural = _("Foods")
        ordering = ("name",)
        indexes = [
            GinIndex(name=f'gin_index_name_{lc}', fields=[f"name_{lc}"], opclasses=['gin_trgm_ops']) for lc, _ in LANGUAGES
        ] + [GinIndex(name=f'gin_index_name', fields=[f"name"], opclasses=['gin_trgm_ops'])]

    def __str__(self):  # pragma: no cover
        return self.name


class FoodNameSynonyms(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(
        _("Name"), max_length=150, unique=False, blank=False, null=False
    )
    language = models.CharField(max_length=2, blank=False, null=False)

    food = models.ForeignKey(Food, related_name="synonyms", on_delete=models.PROTECT)

    class Meta:
        verbose_name = _("Food Synonym")
        ordering = ("name",)
        indexes = [
            GinIndex(name=f'gin_index_food_synonyms', fields=["name"], opclasses=["gin_trgm_ops"])
        ]

    def __str__(self):  # pragma: no cover
        return self.name


class Nutrient(models.Model):
    """Basic definition of a specific nutrient, e.g., `Vitamin D` or `Sodium, Na`"""

    name = models.CharField(
        _("Name"), max_length=150, unique=True, blank=False, null=False
    )

    # This nutrients default unit
    unit = models.ForeignKey(Unit, on_delete=models.PROTECT)

    class Meta:
        verbose_name = _("Nutrient")
        verbose_name_plural = _("Nutrients")

    def __str__(self):  # pragma: no cover
        return self.name


class MeasuredNutrient(models.Model):
    """Groups several Nutrients together; each food can have multiple Nutrients"""

    food = models.ForeignKey(Food, related_name="nutrients", on_delete=models.CASCADE)

    # `amount` is either used by it self, or as lower range limit together with `amount_max`
    amount = models.DecimalField(
        _("Amount"), max_digits=10, decimal_places=4, blank=False
    )

    # statistical measurements
    min = models.DecimalField(_("Min"), max_digits=10, decimal_places=4, blank=False)
    max = models.DecimalField(_("Max"), max_digits=10, decimal_places=4, blank=False)
    median = models.DecimalField(
        _("Median"), max_digits=10, decimal_places=4, blank=False
    )

    class Meta:
        verbose_name = _("Nutrient")
        verbose_name_plural = _("Nutrients")

    def __str__(self):  # pragma: no cover
        return self.name


# class NutritionalValues(models.Model):
#     nutrient_group = models.ForeignKey(Nutrients, related_name="nutritional_values", on_delete=models.CASCADE)

#     kcal = models.PositiveSmallIntegerField(_("kcal"), blank=True, null=True)
#     total_fat = models.DecimalField(
#         _("Total Fat"), max_digits=10, decimal_places=4, blank=True, null=True
#     )
#     saturated_fat = models.DecimalField(
#         _("Saturated Fat"), max_digits=10, decimal_places=4, blank=True, null=True
#     )
#     polyunsaturated_fat = models.DecimalField(
#         _("Poly-Unsaturated Fat"),
#         max_digits=10,
#         decimal_places=4,
#         blank=True,
#         null=True,
#     )
#     monounsaturated_fat = models.DecimalField(
#         _("Mono-Saturated Fat"), max_digits=10, decimal_places=4, blank=True, null=True
#     )
#     cholestoral = models.DecimalField(
#         _("Cholestoral"), max_digits=10, decimal_places=4, blank=True, null=True
#     )
#     sodium = models.DecimalField(
#         _("Sodium"), max_digits=10, decimal_places=4, blank=True, null=True
#     )
#     total_carbohydrates = models.DecimalField(
#         _("Total Carbohydrates"), max_digits=10, decimal_places=4, blank=True, null=True
#     )
#     carbohydrate_dietary_fiber = models.DecimalField(
#         _("Dietary Fiber"),
#         max_digits=6,
#         decimal_places=4,
#         blank=True,
#         null=True,
#     )
#     carbohydrate_sugar = models.DecimalField(
#         _("Sugar"), max_digits=6, decimal_places=4, blank=True, null=True
#     )
#     protein = models.DecimalField(
#         _("Protein"), max_digits=6, decimal_places=4, blank=True, null=True
#     )
#     lactose = models.DecimalField(
#         _("Lactose"), max_digits=6, decimal_places=4, blank=True, null=True
#     )
#     fructose = models.DecimalField(
#         _("Fructose"), max_digits=6, decimal_places=4, blank=True, null=True
#     )
#     glucose = models.DecimalField(
#         _("Glucose"), max_digits=6, decimal_places=4, blank=True, null=True
#     )

#     def clean(self):
#         # TODO: Should be replaced by constraints if possible?
#         check_dependent_fields(
#             self.total_fat, self.saturated_fat, _("total_fat"), _("saturated_fat")
#         )
#         check_dependent_fields(
#             self.total_fat, self.polyunsaturated_fat, _("total_fat"), _("saturated_fat")
#         )
#         check_dependent_fields(
#             self.total_fat,
#             self.monounsaturated_fat,
#             _("total_fat"),
#             _("monounsaturated_fat"),
#         )
#         check_dependent_fields(
#             self.total_carbohydrates,
#             self.carbohydrate_dietary_fiber,
#             _("total_carbohydrates"),
#             _("carbohydrate_dietary_fiber"),
#         )
#         check_dependent_fields(
#             self.total_carbohydrates,
#             self.carbohydrate_sugar,
#             _("total_carbohydrates"),
#             _("carbohydrate_sugar"),
#         )
