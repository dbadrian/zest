import logging

from rest_framework import serializers, validators
import drf_serpy as serpy

from shared.serializers import (
    NonEmptyStringModelSerializerMixin,
    NonEmptyStringSerializerMixinSerpy,
    NonNullModelSerializerMixinSerpy,
    SerpyFloatFieldDefault,
    SerpyKeyField,
    TranslatedModelSerializer,
    NonNullModelSerializerMixin,
    NormalizedDecimalFieldMixin,
    TranslatedModelSerializerMixinSerpy,
)
from units.serializers import UseUnitSerializer
from zest.settings.base.zest import ERROR, ERROR_META_MULTILINGUAL
from .models import Food, FoodNameSynonyms, Nutrient, MeasuredNutrient

logger = logging.getLogger(__name__)


def partial_model_update(data: dict, instance) -> None:
    for k, v in data.items():
        setattr(instance, k, v)
    instance.save()


class NutrientReadOnlySerializer(NonNullModelSerializerMixin, serializers.Serializer):
    name = serializers.CharField()
    unit = UseUnitSerializer()


class NutrientSerializer(
    NonNullModelSerializerMixin,
    NormalizedDecimalFieldMixin,
    serializers.ModelSerializer,
):

    unit = UseUnitSerializer()

    class Meta:
        fields = (
            "name",
            "unit",
        )
        model = Nutrient


# class MeasuredNutrientReadOnlySerializer(
#         NonNullModelSerializerMixin,
#         serializers.Serializer,
# ):
#     food = serializers.UUIDField(read_only=True)
#     nutrient = NutrientReadOnlySerializer()


#     language = serializers.CharField(read_only=True)
#     similarity = serializers.FloatField(default=0.0, read_only=True)

#     class Meta:
#         fields = (
#             "name",
#             "nutrient",
#             "amount",
#             "min",
#             "max",
#             "median",
#         )
#         model = MeasuredNutrient


class MeasuredNutrientReadOnlySerializer(
    NonNullModelSerializerMixin,
    NormalizedDecimalFieldMixin,
    serializers.ModelSerializer,
):

    unit = UseUnitSerializer()
    nutrient = NutrientReadOnlySerializer()

    class Meta:
        fields = (
            "name",
            "nutrient",
            "amount",
            "min",
            "max",
            "median",
        )
        model = MeasuredNutrient


class MeasuredNutrientSerializer(
    NonNullModelSerializerMixin,
    NormalizedDecimalFieldMixin,
    serializers.ModelSerializer,
):

    unit = UseUnitSerializer()
    nutrient = NutrientSerializer()

    class Meta:
        fields = (
            "name",
            "nutrient",
            "amount",
            "min",
            "max",
            "median",
        )
        model = MeasuredNutrient


class FoodSynonymSerializer(
    NonNullModelSerializerMixin,
    serializers.ModelSerializer,
):
    similarity = serializers.FloatField(default=0.0, read_only=True)

    class Meta:
        fields = ("id", "name", "language", "food", "similarity")
        model = FoodNameSynonyms
        extra_kwargs = {
            "id": {"read_only": True, "required": False},
            "name": {"read_only": False, "required": True},
            "language": {"read_only": False, "required": True},
            "food": {"read_only": False, "required": True},
            "similarity": {"read_only": True, "required": False},
        }


class ReadFoodSynonymSerializer(
    NonNullModelSerializerMixin,
    serializers.Serializer,
):
    id = serializers.UUIDField(read_only=True)
    name = serializers.CharField(read_only=True)
    language = serializers.CharField(read_only=True)
    food = serializers.PrimaryKeyRelatedField(read_only=True)
    similarity = serializers.FloatField(default=0.0, read_only=True)

    name_plural = "food_synonyms"


class ReadFoodSynonymSerializerSerpy(
    NonNullModelSerializerMixinSerpy,
    serpy.Serializer,
):
    id = serpy.StrField(required=False)
    name = serpy.StrField()
    language = serpy.StrField(required=False)
    food = serpy.MethodField()
    similarity = SerpyFloatFieldDefault(default=0.0)

    name_plural = "food_synonyms"

    def get_food(self, obj):
        return getattr(obj, "food_id", None)


# class ReadFoodSynonymSerializer(
#         NonNullModelSerializerMixin,
#         serializers.ModelSerializer,
# ):
#     similarity = serializers.FloatField(default=0.0, read_only=True)

#     class Meta:
#         fields = ("id", "name", "language", "food", "similarity")
#         model = FoodNameSynonyms
#         extra_kwargs = {
#             "id": {
#                 "read_only": True,
#                 "required": False
#             },
#             "name": {
#                 "read_only": True,
#                 "required": True
#             },
#             "language": {
#                 "read_only": True,
#                 "required": True
#             },
#             "food": {
#                 "read_only": True,
#                 "required": True
#             },
#             "similarity": {
#                 "read_only": True,
#                 "required": False
#             },
#         }
#         read_only_fields = ("id", "name", "language", "food", "similarity")

# def create(self, validated_data):
#     nv = validated_data.pop("nutrients", {})

#     food = Food.objects.create(**validated_data)
#     MeasuredNutrient.objects.create(food=food, **nv)
#     return food

# def update(self, instance, validated_data):
#     nv = validated_data.pop("nutrients", None)
#     partial_model_update(validated_data, instance)
#     if nv is not None:
#         partial_model_update(nv, instance.nutrients)

#     return instance


class WriteFoodSerializer(
    NonNullModelSerializerMixin,
    TranslatedModelSerializer,
    serializers.ModelSerializer,
):

    similarity = serializers.FloatField(default=0.0, read_only=True)

    class Meta:
        fields = ["id", "name", "description", "similarity"]
        model = Food
        extra_kwargs = {
            "id": {"read_only": True, "required": False},
            "name": {"read_only": False, "required": True},
            "description": {"read_only": False, "required": False},
        }

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)

    def create(self, validated_data):
        nutrients = validated_data.pop("nutrients", {})
        # FIXME: Nutrients are not updated and used
        food = Food.objects.create(**validated_data)
        return food

    def update(self, instance, validated_data):
        nutrients = validated_data.pop("nutrients", None)
        partial_model_update(validated_data, instance)

        return instance


# class FoodSerializer(
#     NonNullModelSerializerMixin,
#     TranslatedModelSerializer,
#     serializers.ModelSerializer,
# ):

#     similarity = serializers.FloatField(default=0.0, read_only=True)

#     class Meta:
#         fields = ["id", "name", "description", "similarity"]
#         model = Food
#         extra_kwargs = {
#             "id": {"read_only": True, "required": False},
#             "name": {"read_only": False, "required": True},
#             "description": {"read_only": False, "required": False},
#         }

#     def __init__(self, *args, **kwargs):
#         super().__init__(*args, **kwargs)

#     def create(self, validated_data):
#         nutrients = validated_data.pop("nutrients", {})
#         food = Food.objects.create(**validated_data)
#         return food

#     def update(self, instance, validated_data):
#         nutrients = validated_data.pop("nutrients", None)
#         partial_model_update(validated_data, instance)

#         return instance


# class ReadFoodSerializer(
#         NonNullModelSerializerMixin,
#         NonEmptyStringModelSerializerMixin,
#         TranslatedModelSerializer,
#         serializers.ModelSerializer,
# ):

#     synonyms = ReadFoodSynonymSerializer(many=True, required=False)

#     class Meta:
#         fields = (
#             "id",
#             "name",
#             "nutrients",
#             "synonyms",
#             "description",
#         )
#         model = Food
#         extra_kwargs = {
#             "id": {
#                 "read_only": True,
#                 "required": False
#             },
#             # "nutrients": {
#             #     "required": False
#             # },
#             # "description": {
#             #     "required": False
#             # },
#             # "synonyms": {
#             #     "required": False
#             # },
#         }
#         read_only_fields = ['id', 'name', 'nutrients', 'synonyms', 'description']


class ReadFoodSerializer(
    NonNullModelSerializerMixin,
    NonEmptyStringModelSerializerMixin,
    TranslatedModelSerializer,
    serializers.Serializer,
):
    id = serializers.UUIDField(read_only=True)
    name = serializers.CharField(read_only=True)
    # synonyms = ReadFoodSynonymSerializer(many=True, read_only=True, required=False)
    # nutrients = NutrientReadOnlySerializer(read_only=True)
    description = serializers.CharField(read_only=True)
    similarity = serializers.FloatField(default=0.0, read_only=True)

    name_plural = "foods"  # set manually

    # required for the translatedmodelserialize jackin
    class Meta:
        fields = (
            "id",
            "name",
            # "nutrients",
            # "synonyms",
            "description",
            "similarity",
        )
        model = Food


class ReadFoodSerializerSerpy(
    NonEmptyStringSerializerMixinSerpy,
    NonNullModelSerializerMixinSerpy,
    TranslatedModelSerializerMixinSerpy,
    serpy.Serializer,
):
    id = serpy.StrField()  # UUIDField()
    name = serpy.StrField()
    # synonyms = ReadFoodSynonymSerializerSerpy()
    # nutrients = NutrientReadOnlySerializer(read_only=True)
    description = serpy.StrField()
    similarity = SerpyFloatFieldDefault(default=0.0)

    name_plural = "foods"  # set manually

    # required for the translatedmodelserialize jackin
    class Meta:
        model = Food


class UseFoodSerializerSerpy(serpy.Serializer):
    id = serpy.StrField()  # UUIDField()


# Use this one if utilize Food
class UseFoodSerializer(serializers.ModelSerializer):
    id = serializers.UUIDField()

    class Meta:
        fields = ("id",)
        model = Food
        extra_kwargs = {"id": {"required": True, "read_only": True}}
        read_only_fields = ["id"]

    def validate(self, data):
        return data
