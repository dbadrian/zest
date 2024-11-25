import decimal
from rest_framework import serializers
import drf_serpy as serpy

from shared.serializers import (
    NonEmptyStringSerializerMixinSerpy,
    NonNullModelSerializerMixinSerpy,
    NormalizedDecimalField,
    SerpyFloatFieldDefault,
    TranslatedModelSerializer,
    NormalizedDecimalFieldMixin,
    NonNullModelSerializerMixin,
    NonEmptyStringModelSerializerMixin,
    TranslatedModelSerializerMixinSerpy,
)
from .models import Unit


class UnitSerializer(
    NonNullModelSerializerMixin,
    NonEmptyStringModelSerializerMixin,
    NormalizedDecimalFieldMixin,
    TranslatedModelSerializer,
    serializers.ModelSerializer,
):

    class Meta:
        fields = (
            "id",
            "name",
            "name_plural",
            "abbreviation",
            "base_unit",
            "conversion_factor",
            "unit_system",
            "has_conversion",
            "is_metric",
            "is_imperial",
            "is_us",
        )
        model = Unit


class ReadUnitSerializerSerpy(
    NonEmptyStringSerializerMixinSerpy,
    NonNullModelSerializerMixinSerpy,
    TranslatedModelSerializerMixinSerpy,
    serpy.Serializer,
):
    id = serpy.IntField()
    name = serpy.StrField()
    name_plural = serpy.StrField()
    abbreviation = serpy.StrField()
    base_unit = serpy.StrField()
    unit_system = serpy.StrField()
    # conversion_factor = NormalizedDecimalField(
    #     read_only=True, max_digits=19, decimal_places=10
    # )
    conversion_factor = serpy.MethodField()

    has_conversion = serpy.MethodField()

    has_conversion = serpy.MethodField()
    is_metric = serpy.MethodField()
    is_imperial = serpy.MethodField()
    is_us = serpy.MethodField()

    similarity = SerpyFloatFieldDefault(default=1.0)

    def get_is_metric(self, obj):
        return obj.is_metric

    def get_is_imperial(self, obj):
        return obj.is_imperial

    def get_is_us(self, obj):
        return obj.is_us

    def get_has_conversion(self, obj):
        return obj.has_conversion

    def get_conversion_factor(self, obj):
        if (cf := getattr(obj, "conversion_factor", None)) is not None:
            if not isinstance(cf, decimal.Decimal):
                cf = decimal.Decimal(str(cf).strip())

            cf = cf.normalize()

            return "{:f}".format(cf)
        else:
            return None

    class Meta:
        model = Unit


class ReadUnitSerializer(
    NonNullModelSerializerMixin,
    NonEmptyStringModelSerializerMixin,
    TranslatedModelSerializer,
    serializers.Serializer,
):
    id = serializers.IntegerField(read_only=True)
    name = serializers.CharField(read_only=True)
    name_plural = serializers.CharField(read_only=True)
    abbreviation = serializers.CharField(read_only=True)
    base_unit = serializers.CharField(read_only=True)
    conversion_factor = NormalizedDecimalField(
        read_only=True, max_digits=19, decimal_places=10
    )
    unit_system = serializers.CharField(read_only=True)

    has_conversion = serializers.SerializerMethodField(read_only=True)
    is_metric = serializers.SerializerMethodField(read_only=True)
    is_imperial = serializers.SerializerMethodField(read_only=True)
    is_us = serializers.SerializerMethodField(read_only=True)

    similarity = serializers.FloatField(default=1.0, read_only=True)

    def get_is_metric(self, obj):
        return obj.is_metric

    def get_is_imperial(self, obj):
        return obj.is_imperial

    def get_is_us(self, obj):
        return obj.is_us

    def get_has_conversion(self, obj):
        return obj.has_conversion

    class Meta:
        fields = (
            "id",
            "name",
            "name_plural",
            "abbreviation",
            "base_unit",
            "conversion_factor",
            "unit_system",
            "has_conversion",
            "is_metric",
            "is_imperial",
            "is_us",
        )
        model = Unit
        read_only_fields = [
            "id",
            "name",
            "name_plural",
            "abbreviation",
            "base_unit",
            "conversion_factor",
            "unit_system",
            "has_conversion",
            "is_metric",
            "is_imperial",
            "is_us",
        ]


class UseUnitSerializer(
    serializers.ModelSerializer,
):
    id = serializers.IntegerField()

    class Meta:
        fields = ("id",)
        model = Unit
        extra_kwargs = {"id": {"required": True}}
