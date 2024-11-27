import logging
import decimal
from typing import Any, Dict, List, Type

from rest_framework import serializers
import drf_serpy as serpy

from shared.serializers import (
    SerpyContextSerializer,
    NonEmptyStringSerializerMixinSerpy,
    NonNullModelSerializerMixinSerpy,
    NormalizedDecimalFieldMixin,
    NonNullModelSerializerMixin,
    NonEmptyStringModelSerializerMixin,
)
from units.serializers import (
    ReadUnitSerializer,
    ReadUnitSerializerSerpy,
    UseUnitSerializer,
)
from foods.serializers import (
    ReadFoodSerializer,
    ReadFoodSerializerSerpy,
    UseFoodSerializer,
)
from units.models import Unit
from foods.models import Food

from ..models import Ingredient, IngredientGroup
from ..utils import update_nested_positional_group

logger = logging.getLogger(__name__)


class ReadIngredientSerializerSerpy(
    NonNullModelSerializerMixinSerpy,
    NonEmptyStringSerializerMixinSerpy,
    SerpyContextSerializer,
):
    # execute those before unit
    amount = serpy.MethodField()
    amount_max = serpy.MethodField()

    unit = ReadUnitSerializerSerpy()
    food = ReadFoodSerializerSerpy()

    details = serpy.StrField()

    class Meta:
        model = Ingredient

    def get_amount(self, obj):
        # if self.context is None or self.context["servings"] is None:
        #     servings = 1
        # else:
        #     servings = int(self.context["servings"])
        #     if self.context is None or servings is None:
        #         servings = 1  # default is already scaled

        # print(type(obj.amount), type(servings))
        print(self.context)
        if (
            default_serving_size := self.context.get("default_serving_size")
        ) is not None:
            amount = obj.amount / default_serving_size * self.context["servings"]
        else:
            amount = obj.amount

        if (
            self.context is not None
            and "to_metric" in self.context
            and self.context["to_metric"]
            and obj.unit.has_conversion
        ):
            amount, unit_name = obj.unit.convert_amount_to_metric(amount)

            try:
                obj.unit = Unit.objects.get(abbreviation_en=unit_name)
            except Unit.DoesNotExist:
                # if there is no abbreviation set, ignore it.
                print(
                    f"Warning: Some abbreviation was requested, but never set. Consider correcting the entry for `{obj.unit.name}`."
                )
                print(
                    "In practice this above error should not happen, and something fishy is going on in the serialization routine for Ingredients/Unit wrt to language issues?"
                )

        return "{:f}".format(amount.normalize())

    def get_amount_max(self, obj):
        if obj.amount_max is not None:
            # if self.context is None or self.context["servings"] is None:
            #     servings = 1
            # else:
            #     servings = int(self.context["servings"])
            #     if self.context is None or servings is None:
            #         servings = 1  # default is already scaled

            if (
                default_serving_size := self.context.get("default_serving_size")
            ) is not None:
                amount_max = (
                    obj.amount_max / default_serving_size * self.context["servings"]
                )
            else:
                amount_max = obj.amount_max

            # FIXME: We could optimize this by storing the test results from `amount`
            if (
                self.context is not None
                and "to_metric" in self.context
                and self.context["to_metric"]
                and obj.unit.has_conversion
            ):
                amount_max, _ = obj.unit.convert_amount_to_metric(amount_max)

            return "{:f}".format(amount_max.normalize())

        return None

    def to_value(self, instance: Type[Any]) -> Dict | List:
        return super().to_value(instance)


class ReadIngredientSerializer(
    NonNullModelSerializerMixin,
    NonEmptyStringModelSerializerMixin,
    NormalizedDecimalFieldMixin,
    serializers.ModelSerializer,
):
    unit = ReadUnitSerializer()
    food = ReadFoodSerializer()

    class Meta:
        model = Ingredient
        fields = (
            "amount",
            "amount_max",
            "unit",
            "food",
            "details",
        )

    def to_representation(self, instance):
        # print(self.context)
        servings = self.context["servings"]
        instance.amount = instance.amount * servings
        if instance.amount_max:
            instance.amount_max = instance.amount_max * servings

        if (
            "to_metric" in self.context
            and self.context["to_metric"]
            and instance.unit.has_conversion
        ):
            amount, unit_name = instance.unit.convert_amount_to_metric(instance.amount)
            instance.amount = amount

            if instance.amount_max:
                instance.amount_max, _ = instance.unit.convert_amount_to_metric(
                    instance.amount_max
                )

            # TODO: bit hacky. find the unit according to the englisch abbreviation field
            # as those do match the SI unit and are garantueed to be set
            try:
                instance.unit = Unit.objects.get(abbreviation_en=unit_name)
            except Unit.DoesNotExist:
                # if there is no abbreviation set, ignore it.
                print(
                    f"Warning: Some abbreviation was requested, but never set. Consider correcting the entry for `{instance.unit.name}`."
                )
                print(
                    "In practice this above error should not happen, and something fishy is going on in the serialization routine for Ingredients/Unit wrt to language issues?"
                )
        try:
            ret = super().to_representation(instance)
        except decimal.InvalidOperation:
            raise serializers.ValidationError(
                {
                    "detail": "Calculation error in ingredient servings scaling. Probably `servings` was set too large."
                }
            )

        return ret


class ReadIngredientGroupSerializerSerpy(SerpyContextSerializer):

    # ingredients = ReadIngredientSerializerSerpy()
    name = serpy.StrField()
    ingredients = ReadIngredientSerializerSerpy(many=True)

    # def get_ingredients(self, obj):
    #     return ReadIngredientSerializerSerpy(
    #         obj.ingredients.all(), many=True, context=self.context
    #     ).data

    class Meta:
        model = IngredientGroup
        # fields = ("name", "ingredients")
        # extra_kwargs = {
        #     # "id": {"read_only": False, "required": False},
        # }


class ReadIngredientGroupSerializer(serializers.ModelSerializer):
    ingredients = ReadIngredientSerializer(many=True)

    class Meta:
        model = IngredientGroup
        fields = ("name", "ingredients")
        extra_kwargs = {
            # "id": {"read_only": False, "required": False},
        }


class WriteIngredientSerializer(
    NonNullModelSerializerMixin,
    NonEmptyStringModelSerializerMixin,
    NormalizedDecimalFieldMixin,
    serializers.ModelSerializer,
):

    unit = UseUnitSerializer()
    food = UseFoodSerializer()

    class Meta:
        model = Ingredient
        fields = (
            "amount",
            "amount_max",
            "unit",
            "food",
            "details",
        )

    def validate(self, data):
        if (
            "amount_max" in data
            and data["amount_max"]
            and data["amount_max"] <= data["amount"]
        ):
            raise serializers.ValidationError(
                f"If `amount_max` is set, it needs to be strictly larger \
                than `amount`, but was amount_max={data['amount_max']} and amount={data['amount']}"
            )
        return data


class WriteIngredientGroupSerializer(serializers.ModelSerializer):
    ingredients = WriteIngredientSerializer(many=True)

    class Meta:
        model = IngredientGroup
        fields = ("name", "ingredients")
        extra_kwargs = {
            # "id": {"read_only": False, "required": False},
        }

    def create(self, validated_data):
        logger.debug(f"Creating IngGr from validated_data={validated_data}")

        if "id" in validated_data:
            raise serializers.ValidationError(
                "`id` submitted for object creation. This is not allowed."
            )

        ingredients_data = validated_data.pop("ingredients")
        group = IngredientGroup.objects.create(**validated_data)

        for new_pos, ingredient in enumerate(ingredients_data, start=1):
            if "id" in ingredient:
                raise serializers.ValidationError(
                    "`id` submitted for object creation. This is not allowed."
                )
            ingredient["position"] = new_pos
            ingredient["group"] = group

            # TODO: This should more safely check if the object exists.
            # Technically, the frontend should already prevent the user from doing it, but maybe we should handle this with a better message.
            ingredient["unit"] = Unit.objects.get(id=ingredient["unit"]["id"])
            ingredient["food"] = Food.objects.get(id=ingredient["food"]["id"])

            Ingredient.objects.create(**ingredient)

        return group

    def update(self, instance, validated_data):
        logger.debug(f"Updating new IngGr from validated_data={validated_data}")

        # Update outer group first
        instance.name = validated_data.get("name", instance.name)
        instance.save()

        # Update inner elements
        ingredients_update = validated_data.pop("ingredients")
        update_nested_positional_group(
            instance,
            ingredients_update,
            Ingredient,
            "id",
            "position",
            "group",
        )

        return instance
