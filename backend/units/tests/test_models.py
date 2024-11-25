from django.test import TestCase, TransactionTestCase
from django.db import IntegrityError, transaction, utils
import logging

from ..models import Unit, SIBaseUnits, UnitSystem

logger = logging.getLogger(__name__)
# pylint: disable=no-member


class UnitModelTest(TestCase):
    """ units.models.Unit """

    def setUp(self):
        Unit.objects.create(
            name="Unit",
            name_plural="Units",
            abbreviation="u",
            base_unit=SIBaseUnits.KILOGRAM,
            conversion_factor=1,
            unit_system=UnitSystem.METRIC,
        )

    def test_unit_non_empty_name(self):
        """Test name must be set/not empty"""
        with transaction.atomic():
            self.assertRaises(
                IntegrityError,
                Unit.objects.create,
                base_unit=SIBaseUnits.KILOGRAM,
                conversion_factor=1,
            )


        with transaction.atomic():
            self.assertRaises(
                IntegrityError,
                Unit.objects.create,
                name="",
                base_unit=SIBaseUnits.KILOGRAM,
                conversion_factor=1,
            )


    def test_unit_unique_name(self):
        # """Test uniqueness contraint for pair (name, unit_system)"""
        with transaction.atomic():
            self.assertRaises(
                IntegrityError,
                Unit.objects.create,
                name="Unit",
                base_unit=SIBaseUnits.KILOGRAM,
                conversion_factor=1,
                unit_system=UnitSystem.METRIC,
            )

        # Same name, but unit_system differs
        Unit.objects.create(
            name="Unit",
            base_unit=SIBaseUnits.KILOGRAM,
            conversion_factor=1,
            unit_system=UnitSystem.IMP,
        )

        Unit.objects.create(
            name="Unit",
            base_unit=SIBaseUnits.KILOGRAM,
            conversion_factor=1,
            unit_system=UnitSystem.US,
        )

    def test_unit_unique_name_plural(self):
        """Test uniqueness contraint for pair (name_plural, unit_system)"""
        with transaction.atomic():
            self.assertRaises(
            IntegrityError,
            Unit.objects.create,
            name="Unit2",
            name_plural="Units",
            base_unit=SIBaseUnits.KILOGRAM,
            conversion_factor=1,
            unit_system=UnitSystem.METRIC,
        )

        # again, different unit_system is allowed for differentiation
        Unit.objects.create(
            name="Unit2",
            name_plural="Units",
            base_unit=SIBaseUnits.KILOGRAM,
            conversion_factor=1,
            unit_system=UnitSystem.US,
        )

    def test_unit_unique_abbreviation(self):
        """Test uniqueness contraint for pair (abbreviation, unit_system)"""
        with transaction.atomic():
            self.assertRaises(
                IntegrityError,
                Unit.objects.create,
                name="Unit2",
                name_plural="Units2",
                abbreviation="u",
                base_unit=SIBaseUnits.KILOGRAM,
                conversion_factor=1,
                unit_system=UnitSystem.METRIC,
            )

        Unit.objects.create(
            name="Unit2",
            name_plural="Units2",
            abbreviation="u",
            base_unit=SIBaseUnits.KILOGRAM,
            conversion_factor=1,
            unit_system=UnitSystem.US,
        )

    def test_unit_allow_empty_base_unit(self):
        """Test that emptu base-unit can pass"""
        Unit.objects.create(name="Unit123")

    def test_unit_empty_base_unit_requires_empty_conversion_factor(self):
        """Test that empty base-unit requires empty conversion factor"""
        with transaction.atomic():
            self.assertRaises(
                IntegrityError,
                Unit.objects.create,
                name="Unit123", conversion_factor=1.222
            )


    def test_unit_base_unit_requires_conversion_factor(self):
        """Test that empty base-unit requires empty conversion factor"""
        with transaction.atomic():
            try:
                Unit.objects.create(name="Unit123", base_unit=SIBaseUnits.KILOGRAM)
            except IntegrityError:
                pass

    def test_unit_allowed_base_units(self):
        """Test validness of supplied base-units"""
        for idx, base_unit in enumerate(SIBaseUnits):
            Unit.objects.create(
                name=f"newUnit{idx}",
                base_unit=base_unit,
                conversion_factor=1,
                unit_system=UnitSystem.METRIC,
            )

        with transaction.atomic():
            self.assertRaises(
                IntegrityError,
                Unit.objects.create,
                    name="Unit5",
                    base_unit="NV",
                    conversion_factor=1,
                    unit_system=UnitSystem.METRIC,
                )

        with transaction.atomic():
            self.assertRaises(
                utils.DataError,
                Unit.objects.create,
                    name="Unit5",
                    base_unit="NOTVALIDTOOLONG",
                    conversion_factor=1,
                    unit_system=UnitSystem.METRIC,
                )

    def test_unit_non_zero_positive_conversion_factor(self):
        """Test non-zero, positive constraint on Unit's conversion_factor field"""
        with transaction.atomic():
            self.assertRaises(
                IntegrityError,
                Unit.objects.create,
                name="UnitP",
                abbreviation="up",
                base_unit=SIBaseUnits.KILOGRAM,
                conversion_factor=0,
                )

        unit_3 = Unit.objects.create(
            name="Unit3",
            abbreviation="u3",
            base_unit=SIBaseUnits.KILOGRAM,
            conversion_factor=1.22,
        )
        from decimal import Decimal
        self.assertEqual(unit_3.conversion_factor, Decimal(1.22))

    def test_unit_non_zero_negative_conversion_factor(self):
        """Test non-zero, negative constraint on Unit's conversion_factor field"""
        with transaction.atomic():
            self.assertRaises(
                IntegrityError,
                Unit.objects.create,
                name="UnitP",
                abbreviation="up",
                base_unit=SIBaseUnits.KILOGRAM,
                conversion_factor=-0.00001,
            )

    def test_unit_allowed_unit_systems(self):
        """Test validness of supplied unit-system"""
        for idx, system in enumerate(UnitSystem):
            Unit.objects.create(
                name=f"newUnit{idx}",
                unit_system=system,
            )

        with transaction.atomic():
            self.assertRaises(
                IntegrityError,
                Unit.objects.create,
                name="Unit5",
                unit_system="NV",
            )

        with transaction.atomic():
            self.assertRaises(
                utils.DataError,
                Unit.objects.create,
                name="Unit5",
                unit_system="NOTVALIDTOOLONG",
            )


    def test_unit_has_conversion(self):
        obj = Unit.objects.create(name="hasConvUnit1")
        self.assertFalse(obj.has_conversion)
        obj = Unit.objects.create(
            name="hasConvUnit2",
            base_unit=SIBaseUnits.KILOGRAM,
            conversion_factor=0.1,
        )
        self.assertTrue(obj.has_conversion)

    def test_unit_is_metric(self):
        for idx, system in enumerate(UnitSystem):
            obj = Unit.objects.create(
                name=f"IsMetricUnit{idx}",
                base_unit=SIBaseUnits.KILOGRAM,
                conversion_factor=0.1,
                unit_system=system,
            )
        if system == UnitSystem.METRIC:
            self.assertTrue(obj.is_metric)
        else:
            self.assertFalse(obj.is_metric)

    def test_unit_is_imperial(self):
        for idx, system in enumerate(UnitSystem):
            obj = Unit.objects.create(
                name=f"IsImperialUnit{idx}",
                base_unit=SIBaseUnits.KILOGRAM,
                conversion_factor=0.1,
                unit_system=system,
            )
        if system == UnitSystem.IMP:
            self.assertTrue(obj.is_imperial)
        else:
            self.assertFalse(obj.is_imperial)

    def test_unit_is_us(self):
        for idx, system in enumerate(UnitSystem):
            obj = Unit.objects.create(
                name=f"IsUSlUnit{idx}",
                base_unit=SIBaseUnits.KILOGRAM,
                conversion_factor=0.1,
                unit_system=system,
            )
        if system == UnitSystem.US:
            self.assertTrue(obj.is_us)
        else:
            self.assertFalse(obj.is_us)
            
    def test_unit_is_shakkanhou(self):
        for idx, system in enumerate(UnitSystem):
            obj = Unit.objects.create(
                name=f"IsUSlUnit{idx}",
                base_unit=SIBaseUnits.KILOGRAM,
                conversion_factor=0.1,
                unit_system=system,
            )
        if system == UnitSystem.JAP:
            self.assertTrue(obj.is_shakkanhou)
        else:
            self.assertFalse(obj.is_shakkanhou)

    def test_unit_is_dimensionless(self):
        for idx, system in enumerate(UnitSystem):
            obj = Unit.objects.create(
                name=f"IsUSlUnit{idx}",
                base_unit=SIBaseUnits.KILOGRAM,
                conversion_factor=0.1,
                unit_system=system,
            )
        if system == UnitSystem.DIMENSIONLESS:
            self.assertTrue(obj.is_dimensionless)
        else:
            self.assertFalse(obj.is_dimensionless)

    def test_unit_convert_amount_to_base_unit_if_no_base_unit(self):
        AMOUNT = 1.337
        NAME = "UnitNoBaseConversion"
        obj = Unit.objects.create(name=NAME, unit_system=UnitSystem.METRIC)
        ret = obj.convert_amount_to_base_unit(AMOUNT)
        self.assertEqual(ret, (AMOUNT, NAME, UnitSystem.METRIC))
        
        AMOUNT2 = 1.337
        NAME = "UnitNoBaseConversion"
        obj2 = Unit.objects.create(name=NAME, unit_system=UnitSystem.US)
        ret2 = obj2.convert_amount_to_base_unit(AMOUNT2)
        self.assertEqual(ret2, (AMOUNT, NAME, UnitSystem.US))

    def test_unit_convert_amount_to_base_unit_kg(self):
        AMOUNT = 1.337
        NAME = "UnitWithBaseConversion"
        CONVFAC = 0.123234
        obj = Unit.objects.create(
            name=NAME,
            base_unit=SIBaseUnits.KILOGRAM,
            conversion_factor=CONVFAC,
            unit_system=UnitSystem.METRIC,
        )
        ret = obj.convert_amount_to_base_unit(AMOUNT)
        self.assertEqual(ret, (AMOUNT * CONVFAC, SIBaseUnits.KILOGRAM, UnitSystem.METRIC))

    def test_unit_convert_amount_to_metric(self):
        # sanity check; already metric
        AMOUNT = 1.112
        obj = Unit.objects.create(
            name_en="cup",
            unit_system=UnitSystem.METRIC
        )
        ret = obj.convert_amount_to_metric(AMOUNT)
        self.assertEqual(ret, (AMOUNT, "cup"))
        
        # sanity check; already metric with an abbreviation
        AMOUNT = 1.112
        obj = Unit.objects.create(
            name_en="cup2",
            abbreviation_en="c.",
            unit_system=UnitSystem.METRIC
        )
        ret = obj.convert_amount_to_metric(AMOUNT)
        self.assertEqual(ret, (AMOUNT, "c."))

        CONVFAC = 0.2365882365 
        obj = Unit.objects.create(
            name_en="cup3",
            base_unit=SIBaseUnits.LITER,
            conversion_factor=CONVFAC,
            unit_system=UnitSystem.US
            
        )
        ret = obj.convert_amount_to_metric(AMOUNT)
        self.assertEqual(ret, (AMOUNT * CONVFAC, SIBaseUnits.LITER))