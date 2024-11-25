from rest_framework import serializers
import drf_serpy as serpy


from shared.serializers import (
    NonNullModelSerializerMixinSerpy,
    NonEmptyStringSerializerMixinSerpy,
    TranslatedModelSerializerMixinSerpy,
    TranslatedModelSerializer,
    NormalizedDecimalFieldMixin,
    NonNullModelSerializerMixin,
    NonEmptyStringModelSerializerMixin,
)
from ..models.category import RecipeCategory


class ReadRecipeCategorySerializerSerpy(
    NonNullModelSerializerMixinSerpy,
    NonEmptyStringSerializerMixinSerpy,
    TranslatedModelSerializerMixinSerpy,
    serpy.Serializer,
):

    id = serpy.IntField()
    name = serpy.StrField()
    name_plural = serpy.StrField()

    class Meta:
        model = RecipeCategory


class ReadRecipeCategorySerializer(
    NonNullModelSerializerMixin,
    NonEmptyStringModelSerializerMixin,
    TranslatedModelSerializer,
    serializers.ModelSerializer,
):

    class Meta:
        fields = (
            "id",
            "name",
            "name_plural",
        )
        model = RecipeCategory
        read_only_fields = ["id", "name", "name_plural"]


class WriteRecipeCategorySerializer(
    NonNullModelSerializerMixin,
    NonEmptyStringModelSerializerMixin,
    TranslatedModelSerializer,
    serializers.ModelSerializer,
):
    id = serializers.IntegerField()

    class Meta:
        fields = ("id",)
        model = RecipeCategory
        extra_kwargs = {"id": {"required": True}}
