# -*- coding: utf-8 -*-
from typing import Optional, Tuple
from numbers import Number
from django.core.exceptions import ValidationError
from django.utils.translation import gettext_lazy as _
from django.db import models
from django.db.models import Q

from shared.utils.generic import check_dependent_fields

UNIT_NAME_MAX_LENGTH = 30
UNIT_ABV_MAX_LENGTH = 10

IMPERIAL_ABV = "imp."
US_ABV = "US"
METRIC_ABV = "Metric"
JAP_ABV = "Shakkanhou"
DIMENSIONLESS_ABV = ""


class SIBaseUnits(models.TextChoices):
    KILOGRAM = "kg", _("Kilogram")
    LITER = "l", _("Liter")


class UnitSystem(models.TextChoices):
    IMP = IMPERIAL_ABV, _("Imperial")
    US = US_ABV, _("US customary")
    METRIC = METRIC_ABV, _("Metric")
    JAP = JAP_ABV, _("Shakkanhō")
    DIMENSIONLESS = DIMENSIONLESS_ABV, _("")
    # TODO: Need another option for things which are not part of any metric system
    # such as "pinch"/"prise", "piece" etc.


class Unit(models.Model):

    name = models.CharField(
        _("Name"), max_length=UNIT_NAME_MAX_LENGTH, blank=False, default=None
    )
    name_plural = models.CharField(
        _("Name (plural)"), max_length=UNIT_NAME_MAX_LENGTH, blank=True, null=True
    )
    abbreviation = models.CharField(
        _("Abbreviation"), max_length=UNIT_ABV_MAX_LENGTH, blank=True, null=True
    )
    base_unit = models.CharField(
        _("SI Base Unit"),
        max_length=2,
        choices=SIBaseUnits.choices,
        blank=True,
        null=True,
    )
    conversion_factor = models.DecimalField(
        _("Conversion factor"), max_digits=19, decimal_places=10, blank=True, null=True
    )

    unit_system = models.CharField(
        _("Unit System"),
        max_length=10,
        choices=UnitSystem.choices,
        blank=True,
        null=False,
        default=UnitSystem.DIMENSIONLESS,
    )

    class Meta:
        ordering = ["name"]
        verbose_name = _("Unit")
        verbose_name_plural = _("Units")
        constraints = [
            models.CheckConstraint(
                check=~Q(name__exact=""),
                name="%(app_label)s_%(class)s_non_empty_name",
            ),
            models.UniqueConstraint(
                fields=["name", "unit_system"],  # since nmo becomes a prefix
                name="%(app_label)s_%(class)s_unique_combination_name",
            ),
            models.UniqueConstraint(
                fields=["name_plural", "unit_system"],  # since nmo becomes a prefix
                name="%(app_label)s_%(class)s_unique_combination_name_plural",
            ),
            models.UniqueConstraint(
                fields=["abbreviation", "unit_system"],  # since nmo becomes a prefix
                name="%(app_label)s_%(class)s_unique_combination_abbreviation",
            ),
            models.CheckConstraint(
                check=Q(conversion_factor__gt=0),
                name="%(app_label)s_%(class)s_conversion_factor_positive",
            ),
            models.CheckConstraint(
                check=(Q(base_unit__isnull=False) & Q(conversion_factor__isnull=False)) |
                (Q(base_unit__isnull=True) & Q(conversion_factor__isnull=True)),
                name="%(app_label)s_%(class)s_base_unit_requires_conversion_factor",
            ),
            models.CheckConstraint(
                check=Q(base_unit__isnull=True) | Q(base_unit__in=SIBaseUnits.values),
                name="%(app_label)s_%(class)s_base_unit_is_valid",
            ),
            models.CheckConstraint(
                check=Q(unit_system__isnull=True) | Q(unit_system__in=UnitSystem.values),
                name="%(app_label)s_%(class)s_unit_system_is_valid",
            ),
        ]

    def __str__(self):  # pragma: no cover
        if self.is_metric or not self.unit_system:
            return self.name
        else:
            return f"{self.unit_system} {self.name}"

    def clean(self):  # pragma: no cover
        if self.name == "":
            raise ValidationError("Field 'name' must not be empty!")

        # Require that both 'base_unit' and 'conversion_factor'
        # are both set. != acts as a XOR operation.
        check_dependent_fields(   # pragma: no cover  # is actually tested...
            self.base_unit,
            self.conversion_factor,
            "base_unit",  # do not translate
            "conversion_factor",  # do not translate
            bidirectional=True,
        )

    @property
    def has_conversion(self):
        # doppelt haelt besser...ne
        return self.base_unit is not None and self.conversion_factor is not None

    @property
    def is_metric(self):
        return self.unit_system == METRIC_ABV

    @property
    def is_imperial(self):
        return self.unit_system == IMPERIAL_ABV

    @property
    def is_us(self):
        return self.unit_system == US_ABV
    
    @property
    def is_shakkanhou(self):
        return self.unit_system == JAP_ABV
    
    @property
    def is_dimensionless(self):
        return self.unit_system == DIMENSIONLESS_ABV

    def convert_amount_to_base_unit(self, amount) -> Tuple[Number, Optional[str], Optional[str]]:
        if self.has_conversion:
            return (
                amount * self.conversion_factor,
                self.base_unit,
                UnitSystem.METRIC,
            )
        else:
            return (amount, self.name, self.unit_system)

    def convert_amount_to_metric(self, amount) -> Tuple[Number, Optional[str]]:
        if self.unit_system != UnitSystem.METRIC and self.has_conversion:
            return amount * self.conversion_factor, self.base_unit
        else:
            return amount, self.abbreviation if (self.abbreviation is not None and  self.abbreviation) else self.name
