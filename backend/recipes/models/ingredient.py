from typing import Tuple
from decimal import Decimal
from django.utils.translation import gettext_lazy as _
from django.db import models
from django.core.exceptions import ValidationError
from collections import defaultdict

from foods.models import Food
from units.models import Unit


class IngredientGroup(models.Model):
    """Groups several ingredients together. A recipe can
    have multipe ingredient groups
    """

    name = models.CharField(max_length=150)
    recipe = models.ForeignKey("Recipe", related_name="ingredient_groups", on_delete=models.CASCADE)
    position = models.PositiveSmallIntegerField(blank=True, null=True)

    class Meta:
        ordering = ["position"]
        verbose_name = _("IngredientGroup")
        verbose_name_plural = _("IngredientGroups")

    def __str__(self):
        return self.name

    def collect_ingredients(self):
        """
        Collects all ingredients in a dict.

        Will convert all ingredients to an SI-base representation (where possible),
        and aggreagate
        """
        ret = defaultdict(lambda: {"amount": Decimal(), "amount_max": Decimal()})
        for ingredient in self.ingredients.all():
            unit, a, a_max, system = ingredient.get_base_unit_representation()
            ret[(ingredient.name, unit)]["amount"] += a
            ret[(ingredient.name, unit)]["amount_max"] += a_max if a_max else a
        return ret


class Ingredient(models.Model):
    """A measured amount in class(Unit) of class(Food) with notes/instructions."""

    group = models.ForeignKey(IngredientGroup, related_name="ingredients", on_delete=models.CASCADE)

    unit = models.ForeignKey(Unit, on_delete=models.PROTECT)
    # `amount` is either used by it self, or as lower range limit together with `amount_max`
    amount = models.DecimalField(
        _("(Lower) Amount"), max_digits=10, decimal_places=4, blank=False
    )
    # `amount_max` is optional and will be used as upper limit of a range if given
    amount_max = models.DecimalField(
        _("Max. Amount"), max_digits=10, decimal_places=4, blank=True, null=True
    )
    food = models.ForeignKey(Food, on_delete=models.PROTECT)
    # And optional comment for the ingredient
    details = models.TextField(_("Details"), blank=True, null=True)

    # meta information
    position = models.PositiveSmallIntegerField(blank=True, null=True)

    class Meta:
        ordering = ["position"]
        verbose_name = _("Ingredient")
        verbose_name_plural = _("Ingredients")

    def __str__(self):
        return self.name

    def clean(self):
        if self.amount_max and self.amount_max <= self.amount:
            raise ValidationError(f"If `amount_max` is set, it needs to be strictly larger \
                than `amount`, but was amount_max={self.amount_max} and amount={self.amount}")

    @property
    def name(self):
        return self.food.name

    def get_base_unit_representation(self) -> Tuple[str, Decimal, Decimal, str]:
        amount, unit, system = self.unit.convert_amount_to_base_unit(self.amount)
        if self.amount_max is not None:
            amount_max, _, _ = self.unit.convert_amount_to_base_unit(self.amount_max)
        else:
            amount_max = None
        return (unit, amount, amount_max, system)

    def get_nutritional_values(self):
        pass
